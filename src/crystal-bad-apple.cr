module BadApple
  VERSION = "0.1.0"

  ASCII_CHARS = ["@", "#", "%", "?", "*", "+", ";", ":", ",", " "]
  DIR_NAME = "bmps"
  PREFIX = "ba_"
  FPS = 15.000

  class Bitmap
    HEADER_SIZE = 54

    getter width, height, total_pixels, pixels

    def initialize(
      @header : Bytes,
      @width : UInt32,
      @height : UInt32,
      @byte_per_pixel : UInt8,
      @total_pixels : UInt32,
      @data : Bytes,
      @pixels : Array(Array(Pixel))
    )
    end


    def initialize(filepath : String)
      abort "missing file: #{filepath}" if !File.file?(filepath)
      image = File.new(filepath, "r")

      @header = Bytes.new(HEADER_SIZE)
      image.read(@header)

      validate_header!

      @width = IO::ByteFormat::LittleEndian.decode(UInt32, @header[18, 4])
      @height = IO::ByteFormat::LittleEndian.decode(UInt32, @header[22, 4])
      @total_pixels = @width * @height

      @byte_per_pixel = @header[28] // 8
      
      @data = Bytes.new(@total_pixels * @byte_per_pixel)
      image.read(@data)

      @pixels = Array.new(@width) { |i| Array(Pixel).new() }

      create_pixels_from_data()
    end

    def pixel(x : UInt32, y : UInt32)
      @pixels[x][y]
    end

    private def validate_header!
      if @header[0] != 0x42 || @header[1] != 0x4d
        abort "looks like it's not BMP file"
      end
      if IO::ByteFormat::LittleEndian.decode(UInt32, @header[46, 4]) != 0
        abort "Not supported a color palette yet."
      end
    end

    private def create_pixels_from_data
      sliced_data = @data.each_slice(@byte_per_pixel).to_a
      @height.times do |h|
        y = @height - h - 1 
        @width.times do |w|
          x = w
          pix_data = sliced_data.shift
          @pixels[x].unshift(Pixel.new(x: x, y: y, b: pix_data[0], g: pix_data[1], r: pix_data[2]))
        end
      end
    end
  end

  struct Pixel
    getter x, y
    property r, g, b

    def initialize(@x : UInt32, @y : UInt32, @r : UInt8, @g : UInt8, @b : UInt8)
    end

    def grayscale
      @r * 0.3 + @g * 0.59 + @b * 0.11
    end
  end

  class FrameGenerator
    def initialize(
      @bitmap : Bitmap,
      @width : UInt32,
      @height : UInt32)
    end

    def initialize(filepath : String)
      @bitmap = Bitmap.new(filepath)
      @width = @bitmap.width
      @height = @bitmap.height
    end

    def to_frame 
      frame = ""

      @height.times do |y|
        @width.times do |x|
          frame += pixel_to_char(@bitmap.pixel(x: x, y: y))
        end
        frame += "\n"
      end

      frame
    end

    private def pixel_to_char(pixel : Pixel)
      ASCII_CHARS[(pixel.grayscale * ASCII_CHARS.size / 256).to_i]
    end
  end

  class Animation
    def initialize(@frames : Array(String), @duration : Float64, @cycles : Int32)
    end

    def animate
      @cycles.times do |i|
        @frames.each do |frame|
          print frame
          sleep @duration
          system "clear"
        end
      end
    end
  end

  class BadApple
    def initialize
      frames = [] of String

      Dir["#{DIR_NAME}/#{PREFIX}*.bmp"].each do |filepath|
        frames << FrameGenerator.new(filepath).to_frame
      end

      @animation = Animation.new(frames, 1.0 / FPS, frames.size)
    end

    def animate
      @animation.animate()
    end
  end
end

BadApple::BadApple.new.animate()
