module Crystal
  class CodeGenVisitor
  
    def malloc_offsets(type : NilType, dump=false) : UInt64
      0u64
    end

    @offset_cache = {} of Crystal::Type => UInt64

    def malloc_offsets(type, dump=false) : UInt64
      if @offset_cache[type]?
        return @offset_cache[type]
      end
      offsets = 0u64
      ivars = type.all_instance_vars
      is_struct = type.struct?
      puts "#{type} (#{type_id(type)}) #{ivars.size}" if dump
      ivars.each_with_index do |(name, ivar), idx|
        if ivar.type.has_inner_pointers?
          case ivar.type
          when MixedUnionType 
            utype = ivar.type.as(MixedUnionType)
            uoffset = utype.union_types
              .map{ |type| malloc_offsets(type) }
              .reduce(0) { |acc, i| acc | i }
            base_offset = @program.instance_offset_of(type.sizeof_type, idx) +
                     llvm_typer.offset_of(llvm_typer.llvm_type(ivar.type), 1)
            base_bit = base_offset // llvm_typer.pointer_size
            i = 0
            while uoffset != 0
              if (uoffset & 1) != 0
                bit = base_bit + i
                offsets |= (1u32 << bit.to_u32)
                puts " + [mixed] #{name}, #{ivar.type}, #{bit*llvm_typer.pointer_size}" if dump
              else
                bit = base_bit + i
                puts " - [mixed] #{name}, #{ivar.type}, #{bit*llvm_typer.pointer_size}" if dump
              end
              uoffset >>= 1
              i += 1
            end
          when TupleInstanceType, NamedTupleInstanceType
            raise "handling tuple is unimplemented"
          else
            case ivar.type
            when VirtualType
              if ivar.type.as(VirtualType).struct?
                soffset = malloc_offsets(ivar.type)
              end
            when ClassType
              if ivar.type.as(ClassType).struct?
                soffset = malloc_offsets(ivar.type)
              end
            end
            if is_struct
              base_offset = @program.offset_of(type.sizeof_type, idx)
            else
              base_offset = @program.instance_offset_of(type.sizeof_type, idx)
            end
            if soffset
              base_bit = base_offset // llvm_typer.pointer_size
              i = 0
              while soffset != 0
                if (soffset & 1) != 0
                  bit = base_bit + i
                  offsets |= (1u32 << bit.to_u32)
                  puts " + [mixed] #{name}, #{ivar.type}, #{bit*llvm_typer.pointer_size}" if dump
                else
                  bit = base_bit + i
                  puts " - [mixed] #{name}, #{ivar.type}, #{bit*llvm_typer.pointer_size}" if dump
                end
                soffset >>= 1
                i += 1
              end
            else
              bit = base_offset // llvm_typer.pointer_size
              offsets |= (1u64 << bit.to_u64)
              puts " + #{name}, #{ivar.type}, #{base_offset}" if dump
            end
          end
        else
          if is_struct
            offset = @program.offset_of(type.sizeof_type, idx)
          else
            offset = @program.instance_offset_of(type.sizeof_type, idx)
          end
          bit = offset // llvm_typer.pointer_size
          puts " - #{name}, #{ivar.type}, #{offset}" if dump
        end
      end
      @offset_cache[type] = offsets
      offsets
    end

  end
end
