{% unless flag?(:win32) %}
  @[Link("pthread")]
  lib LibC
  end
{% end %}

require "./precise/allocator"

module GC
  def self.init
    Allocator.init
  end

  # :nodoc:
  def self.malloc(size : LibC::SizeT)
    Allocator.malloc(size)
  end

  # :nodoc:
  def self.array_malloc(size : LibC::SizeT)
    Allocator.malloc(size)
  end

  # :nodoc:
  def self.malloc_atomic(size : LibC::SizeT)
    Pointer(Void).new 0
  end

  # :nodoc:
  def self.realloc(ptr : Void*, size : LibC::SizeT)
    {% if false %}
    if Allocator.resize ptr, size
      return ptr
    end
    block_size = Allocator.block_size_for_ptr(ptr)
    newptr = Allocator.malloc(size)
    Intrinsics.memcpy(newptr, ptr, block_size, false)
    newptr
    {% end %}
    Pointer(Void).new 0
  end

  def self.collect
  end

  def self.enable
  end

  def self.disable
  end

  def self.free(pointer : Void*)
    LibC.free(pointer)
  end

  def self.is_heap_ptr(pointer : Void*)
    false
  end

  def self.add_finalizer(object)
  end

  def self.stats
    zero = LibC::ULong.new(0)
    Stats.new(zero, zero, zero, zero, zero)
  end

  def self.prof_stats
    zero = LibC::ULong.new(0)
    ProfStats.new(
      heap_size: zero,
      free_bytes: zero,
      unmapped_bytes: zero,
      bytes_since_gc: zero,
      bytes_before_gc: zero,
      non_gc_bytes: zero,
      gc_no: zero,
      markers_m1: zero,
      bytes_reclaimed_since_gc: zero,
      reclaimed_bytes_before_gc: zero)
  end

  {% unless flag?(:win32) %}
    # :nodoc:
    def self.pthread_create(thread : LibC::PthreadT*, attr : LibC::PthreadAttrT*, start : Void* -> Void*, arg : Void*)
      LibC.pthread_create(thread, attr, start, arg)
    end

    # :nodoc:
    def self.pthread_join(thread : LibC::PthreadT) : Void*
      ret = LibC.pthread_join(thread, out value)
      raise Errno.new("pthread_join") unless ret == 0
      value
    end

    # :nodoc:
    def self.pthread_detach(thread : LibC::PthreadT)
      LibC.pthread_detach(thread)
    end
  {% end %}

  # :nodoc:
  def self.current_thread_stack_bottom
    {Pointer(Void).null, Pointer(Void).null}
  end

  # :nodoc:
  {% if flag?(:preview_mt) %}
    def self.set_stackbottom(thread : Thread, stack_bottom : Void*)
      # NOTE we could store stack_bottom per thread,
      #      and return it in `#current_thread_stack_bottom`,
      #      but there is no actual use for that.
    end
  {% else %}
    def self.set_stackbottom(stack_bottom : Void*)
    end
  {% end %}

  # :nodoc:
  def self.lock_read
  end

  # :nodoc:
  def self.unlock_read
  end

  # :nodoc:
  def self.lock_write
  end

  # :nodoc:
  def self.unlock_write
  end

  # :nodoc:
  def self.push_stack(stack_top, stack_bottom)
  end
end
