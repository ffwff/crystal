require "./allocator/*"

module GC::Allocator
  extend self

  MAX_HEAP_SIZE = 128u64 * 0x1_000_000u64

  # Initializes the memory allocator.
  def init
    heap = LibC.mmap nil, MAX_HEAP_SIZE, LibC::PROT_NONE, 0, -1, 0
    Small.init heap.address
    heap = LibC.mmap nil, MAX_HEAP_SIZE, LibC::PROT_NONE, 0, -1, 0
    Big.init heap.address
  end

  def pages_allocated
    Small.pages_allocated + Big.pages_allocated
  end

  def malloc(size, atomic = false) : Void*
    if size <= Small::Data::MAX_MMAP_SIZE
      Small.malloc size, atomic
    else
      Big.malloc size, atomic
    end
  end

  def resize(ptr : Void*, newsize) : Bool
    if Big.contains_ptr? ptr
      Big.resize ptr, newsize
      true
    elsif Small.contains_ptr? ptr
      Small.block_size_for_ptr(ptr) <= newsize
    else
      false
    end
  end

  def atomic?(ptr) : Bool
    if Small.contains_ptr? ptr
      Small.atomic? ptr
    elsif Big.contains_ptr? ptr
      Big.atomic? ptr
    else
      false
    end
  end

  def marked?(ptr) : Bool
    if Small.contains_ptr? ptr
      Small.marked? ptr
    elsif Big.contains_ptr? ptr
      Big.marked? ptr
    else
      false
    end
  end

  def make_markable(ptr) : Void*?
    if Small.contains_ptr? ptr
      Small.make_markable ptr
    elsif Big.contains_ptr? ptr
      Big.make_markable ptr
    end
  end

  def mark(ptr, value = true) : Nil
    if Small.contains_ptr? ptr
      Small.mark ptr, value
    elsif Big.contains_ptr? ptr
      Big.mark ptr, value
    end
  end

  def block_size_for_ptr(ptr) : Int32
    if Small.contains_ptr? ptr
      Small.block_size_for_ptr ptr
    elsif Big.contains_ptr? ptr
      Big.block_size_for_ptr ptr
    else
      0
    end
  end

  def sweep
    Small.sweep
    Big.sweep
  end
end
