# encoding: ASCII-8BIT

# jpg.rb : Extracts the data from a JPG that is needed for embedding
#
# Copyright April 2008, James Healy.  All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

require 'stringio'

module Prawn
  module Images
    # A convenience class that wraps the logic for extracting the parts
    # of a JPG image that we need to embed them in a PDF
    #
    class PDF < Image
      attr_reader :width, :height
      attr_accessor :scaled_width, :scaled_height

      # Process a new PDF file
      #
      # <tt>:data</tt>:: A binary string of PDF data
      #
      def initialize(data, options = {})
        @data   = data
        @data   = StringIO.new(@data) if @data.is_a?(String)
        @reader = ::PDF::Reader.new(@data)
        @page   = @reader.page(options[:page] || 1)
        attrs   = @page.attributes
        @width  = attrs[:MediaBox][2] - attrs[:MediaBox][0]
        @height = attrs[:MediaBox][3] - attrs[:MediaBox][1]
      end

      # Build a PDF object representing this image in +document+, and return
      # a Reference to it.
      #
      def build_pdf_object(document)
        id   = document.state.store.import_page(@page, :Contents, :MediaBox)
        form = document.state.store[id]

        form.data[:Type] = :XObject
        form.data[:Subtype] = :Form
        form.data[:BBox] = @page.attributes[:MediaBox]
        form << @page.raw_content
        form.data[:Length] = form.stream.size
        form
      end

    end
  end
end
