module GC::Allocator::Big
  extend self

  lib Data
    MAGIC_MMAP     = 0x47727533
    MAX_POOL_SIZE  =      32768
    MAX_ALLOC_SIZE = MAX_POOL_SIZE - sizeof(Data::MmapHeader)

    struct MmapHeader
      magic : LibC::SizeT
      marked : LibC::SizeT
      atomic : LibC::SizeT
      size : LibC::SizeT
    end

    MAGIC_EMPTY = 0

    struct EmptyHeader
      magic : LibC::SizeT
      next_page : EmptyHeader*
    end
  end

  MASK = 0xFFFF_FFFF_FFFF_8000u64

  # Placement address of first pool
  @@start_addr = 0u64

  # Placement address of newest pool
  class_getter placement_addr
  @@placement_addr = 0u64

  # Number of pages the allocator has allocated (number of mmap calls/frames claimed).
  class_getter pages_allocated
  @@pages_allocated = 0

  # empty, reusable pages
  @@empty_pages = Pointer(Data::EmptyHeader).null

  # Initializes the memory allocator.
  def init(@@placement_addr)
    @@start_addr = @@placement_addr
  end

  def contains_ptr?(ptr)
    @@start_addr <= ptr.address < @@placement_addr
  end

  private def new_mmap(bytes : Int, atomic)
    pool_size = sizeof(Data::MmapHeader) + bytes.as(LibC::SizeT)
    abort "pool size must be <= 0x1000" if pool_size > Data::MAX_POOL_SIZE

    npages = pages_for(pool_size)

    if page = @@empty_pages
      addr = page.address
      if npages > 1
        alloc_page(addr + 0x1000, npages - 1)
      end
      @@empty_pages = page.value.next_page
    else
      addr = @@placement_addr
      alloc_page(addr, npages)
      @@placement_addr += Data::MAX_POOL_SIZE
    end

    hdr = Pointer(Data::MmapHeader).new(addr)
    hdr.value.magic = Data::MAGIC_MMAP
    hdr.value.marked = 0
    hdr.value.atomic = atomic ? 1 : 0
    hdr.value.size = (npages * 0x1000) - sizeof(Data::MmapHeader)

    (hdr + 1).as(Void*)
  end

  def malloc(bytes : Int, atomic = false) : Void*
    new_mmap bytes, atomic
  end

  def marked?(ptr : Void*)
    page = Pointer(Data::MmapHeader).new(ptr.address & MASK)
    return page.value.marked == 1
  end

  def make_markable(ptr : Void*) : Void*?
    page = Pointer(Data::MmapHeader).new(ptr.address & MASK)
    return if page.value.marked == 1
    page.value.marked = 1
    return Pointer(Void).new(page.address + sizeof(Data::MmapHeader))
  end

  def atomic?(ptr : Void*)
    page = Pointer(Data::MmapHeader).new(ptr.address & MASK)
    return page.value.atomic == 1
  end

  def mark(ptr : Void*, value = true)
    page = Pointer(Data::MmapHeader).new(ptr.address & MASK)
    page.value.marked = value ? 1 : 0
  end

  def block_size_for_ptr(ptr)
    page = Pointer(Data::MmapHeader).new(ptr.address & MASK)
    page.value.size.to_i32
  end

  def resize(ptr : Void*, newsize : Int)
    pool_size = sizeof(Data::MmapHeader) + newsize.as(LibC::SizeT)
    abort "pool size must be <= 0x1000" if pool_size > Data::MAX_POOL_SIZE

    hdr = Pointer(Data::MmapHeader).new(ptr.address & MASK)
    old_npages = pages_for(hdr.value.size)
    npages = pages_for(pool_size)

    if npages > old_npages
      alloc_page(hdr.address + old_npages * 0x1000, old_npages - npages)
    end
  end

  def sweep
    addr = @@start_addr
    while addr < @@placement_addr.to_u64
      hdr = Pointer(Data::MmapHeader).new(addr)
      if hdr.value.magic == Data::MAGIC_MMAP
        if hdr.value.marked == 0
          npages = pages_for(hdr.value.size)
          if npages > 1
            dealloc_page(hdr.address + 0x1000, npages - 1)
          end
          hdr = Pointer(Data::EmptyHeader).new(addr)
          hdr.value.magic = 0
          hdr.value.next_page = @@empty_pages
          @@empty_pages = hdr
        else
          hdr.value.marked = 0
        end
      end
      addr += Data::MAX_POOL_SIZE
    end
  end

  private def pages_for(x)
    (x + 0x1000 - 1) // 0x1000
  end

  private def alloc_page(addr, npages = 1)
    @@pages_allocated += 1
    LibC.mprotect Pointer(Void).new(addr), 0x1000 * npages, LibC::PROT_READ | LibC::PROT_WRITE
  end

  private def dealloc_page(addr, npages = 1)
  end
end
