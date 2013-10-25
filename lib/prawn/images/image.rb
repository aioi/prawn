# encoding: utf-8
# image.rb : Base class for image info objects
#
# Copyright September 2011, Brad Ediger. All rights reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

require 'digest/sha1'

module Prawn
  module Images
    class Image
      def height_ratio
        self.scaled_height.to_f / self.height.to_f
      end

      def width_ratio
        self.scaled_width.to_f / self.width.to_f
      end

      def calc_image_dimensions(options)
        w = options[:width] || width
        h = options[:height] || height

        if options[:width] && !options[:height]
          wp = w / width.to_f 
          w = width * wp
          h = height * wp
        elsif options[:height] && !options[:width]         
          hp = h / height.to_f
          w = width * hp
          h = height * hp   
        elsif options[:scale] 
          w = width * options[:scale]
          h = height * options[:scale]
        elsif options[:fit] 
          bw, bh = options[:fit]
          bp = bw / bh.to_f
          ip = width / height.to_f
          if ip > bp
            w = bw
            h = bw / ip
          else
            h = bh
            w = bh * ip
          end
        end
        self.scaled_width = w
        self.scaled_height = h

        [w,h]
      end

      def self.detect_image_format(content)
        top = content[0,128]                       

        # Unpack before comparing for JPG header, so as to avoid having to worry
        # about the source string encoding. We just want a byte-by-byte compare.
        if top[0, 3].unpack("C*") == [255, 216, 255]
          return :jpg
        elsif top[0, 8].unpack("C*") == [137, 80, 78, 71, 13, 10, 26, 10]
          return :png
        elsif top[0,5].unpack("C*") == [37, 80, 68, 70, 45]
          return :pdf
        else
          raise Errors::UnsupportedImageType, "image file is an unrecognised format"
        end
      end


    end
  end
end

