module Crystal
  class CodeGenVisitor

    @offset_cache = {} of Crystal::Type => UInt64

    private def tabbed(num, arg)
      if n = num
        n.times do |i|
          print ' '
        end
        puts arg
      end
    end

    private def newtab(tab)
      if tab
        tab.not_nil! + 1
      else
        nil
      end
    end

    def malloc_offsets(type : Type, tab : Int32? = nil) : UInt64
      unless type.has_inner_pointers?
        return 0u64
      end

      if offsets = @offset_cache[type]?
        return offsets
      end

      offsets = 0u64
      psize = llvm_typer.pointer_size

      tabbed tab, type

      case type
      when .struct?, .class?, .metaclass?
        type.all_instance_vars.each_with_index do |(name, ivar), idx|
          itype = ivar.type
          base_offset = if type.struct?
                          @program.offset_of(type.sizeof_type, idx)
                        else
                          @program.instance_offset_of(type.sizeof_type, idx)
                        end
          base_bit = (base_offset // psize).to_u64
          # tabbed tab, " #{itype} => #{@program.size_of(itype)}"
          if itype.has_inner_pointers? && @program.size_of(itype) == psize
            offsets |= (1u64 << base_bit)
            tabbed tab, " + #{name}, #{ivar.type}, #{base_offset} (#{base_bit})"
          elsif itype.has_inner_pointers?
            inner_offsets = malloc_offsets itype, newtab(tab)
            offsets |= (inner_offsets << base_bit)
            tabbed tab, " + #{name}, #{ivar.type}, #{base_offset} (#{base_bit}) bits #{inner_offsets.to_s(2)}"
          else
            tabbed tab, " - #{name}, #{ivar.type}, #{base_offset}"
          end
        end
        @offset_cache[type] = offsets
        return offsets
      when UnionType, MixedUnionType
        if @program.size_of(type) == psize
          return 1u64
        end
        offsets = type.union_types.map do |itype|
          if itype.has_inner_pointers? && @program.size_of(itype) == psize
            1u64
          else
            malloc_offsets itype, newtab(tab)
          end
        end
          .reduce(0u64) { |acc, i| acc | i }
        data_base = llvm_typer.offset_of(llvm_typer.llvm_type(type), 1)
        data_bit = (data_base // psize).to_u64
        return offsets << data_bit
      when ProcInstanceType
        raise "unimplemented proc"
      else
        raise "Unhandled type in `kind`: #{type}"
      end
    end
  end
end
