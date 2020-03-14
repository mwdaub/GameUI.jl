using CSFML, CSFML.LibCSFML

import Base.Threads.Atomic
import Base.Threads.atomic_add!

mutable struct AudioStream
  header::Vector{UInt8}
  data::Channel{UInt8}
  position::Atomic{Int64}
end

AudioStream() = AudioStream(header(typemax(UInt32) - headerSize), Channel{UInt8}(Inf), Atomic{Int64}(1))

const headerSize = UInt32(44)

function header(datalength::UInt32)
  h = zeros(UInt8, headerSize)
  h[1:4] = Vector{UInt8}("RIFF")
  h[5:8] = reinterpret(UInt8, [headerSize + datalength])
  h[9:12] = Vector{UInt8}("WAVE")
  h[13:16] = Vector{UInt8}("fmt ")
  h[17:20] = reinterpret(UInt8, [UInt32(16)])
  h[21] = 0x01
  h[23] = 0x01
  h[25:28] = reinterpret(UInt8, [UInt32(44100)])
  h[29:32] = reinterpret(UInt8, [UInt32(44100 * 2)])
  h[33] = 0x02
  h[35] = 0x10
  h[37:40] = Vector{UInt8}("data")
  h[41:44] = reinterpret(UInt8, [datalength])
  h
end

function read!(dest::Vector{UInt8}, as::AudioStream, num::Int64)
  position = atomic_add!(as.position, num)
  for i = 1:num
    dest[i] = if position <= length(as.header)
      as.header[position]
    else
      take!(as.data)
    end
    position += 1
  end
  num
end

function readc!(data::Ptr{Cvoid}, size::Int64, userdata::Ptr{Cvoid})
  data = unsafe_wrap(Vector{UInt8}, Base.unsafe_convert(Ptr{UInt8}, data), size)
  as = unsafe_pointer_to_objref(userdata)
  read!(data, as, size)
end

function seek!(as::AudioStream, position::Int64)
  as.position[] = position
end

function seekc!(position::Clonglong, userdata::Ptr{Cvoid})
  as = unsafe_pointer_to_objref(userdata)
  seek!(as, position + 1) - 1
end

tell(as::AudioStream) = as.position[]

function tellc(userdata::Ptr{Cvoid})
  as = unsafe_pointer_to_objref(userdata)
  tell(as) - 1
end

getsize(as::AudioStream) = Int64(typemax(UInt32))

function getsizec(userdata::Ptr{Cvoid})
  as = unsafe_pointer_to_objref(userdata)
  getsize(as)
end

function inputstream(as::AudioStream)
  readptr = @cfunction(readc!, Clonglong, (Ptr{Cvoid}, Clonglong, Ptr{Cvoid}))
  seekptr = @cfunction(seekc!, Clonglong, (Clonglong, Ptr{Cvoid}))
  tellptr = @cfunction(tellc, Clonglong, (Ptr{Cvoid},))
  getsizeptr = @cfunction(getsizec, Clonglong, (Ptr{Cvoid},))
  sfInputStream(readptr, seekptr, tellptr, getsizeptr, pointer_from_objref(as))
end

music(as::AudioStream) = sfMusic_createFromStream(Ref(inputstream(as)))
