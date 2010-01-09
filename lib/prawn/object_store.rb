# encoding: utf-8

# object_store.rb : Implements PDF object repository for Prawn
#
# Copyright August 2009, Brad Ediger.  All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

require 'pdf/reader'

module Prawn
  class ObjectStore #:nodoc:
    include Enumerable
    BASE_OBJECTS = %w[info pages root]

    attr_reader :info, :root

    def initialize(opts = {})
      @objects = {}
      @identifiers = []

      # Create required PDF roots
      if opts[:template]
        load_file(opts[:template])
      else
        @info     = ref(opts[:info] || {}).identifier
        pages_obj = ref(:Type => :Pages, :Count => 0, :Kids => [])
        @pages    = pages_obj.identifier
        @root     = root_ref(pages_obj, opts[:outlines]).identifier
      end
    end

    def root_ref(pages, outlines = nil)
      root_hash = {:Type => :Catalog, :Pages => pages }
      root_hash.merge(:Outlines => "") if outlines
      ref(root_hash)
    end

    def ref(data, &block)
      push(size + 1, data, &block)
    end

    def info
      @objects[@info]
    end

    def root
      @objects[@root]
    end

    def pages
      root.data[:Pages]
    end

    # Adds the given reference to the store and returns the reference object.
    # If the object provided is not a Prawn::Reference, one is created from the
    # arguments provided.
    def push(*args, &block)
      reference = if args.first.is_a?(Prawn::Reference)
              args.first
            else
              Prawn::Reference.new(*args, &block)
            end
      @objects[reference.identifier] = reference
      @identifiers << reference.identifier
      reference
    end
    alias_method :<<, :push

    def each
      @identifiers.each do |id|
        yield @objects[id]
      end
    end

    def [](id)
      @objects[id]
    end

    def size
      @identifiers.size
    end
    alias_method :length, :size

    def compact
      # Clear live markers
      each { |o| o.live = false }

      # Recursively mark reachable objects live, starting from the roots
      # (the only objects referenced in the trailer)
      root.mark_live
      info.mark_live

      # Renumber live objects to eliminate gaps (shrink the xref table)
      if @objects.any?{ |_, o| !o.live }
        new_id = 1
        new_objects = {}
        new_identifiers = []

        each do |obj|
          if obj.live
            obj.identifier = new_id
            new_objects[new_id] = obj
            new_identifiers << new_id
            new_id += 1
          end
        end

        @objects = new_objects
        @identifiers = new_identifiers
      end
    end

    private

    def load_file(filename)
      unless File.file?(filename)
        raise ArgumentError, "#{filename} does not exist"
      end

      unless PDF.const_defined?("Hash")
        raise "PDF::Hash not found. Is PDF::Reader > 0.8?"
      end

      hash = PDF::Hash.new(filename)
      src_info = hash.trailer[:Info]
      src_root = hash.trailer[:Root]

      if src_info
        @info = load_object_graph(hash, src_info).identifier
      else
        @info = ref({}).identifier
      end

      if src_root
        @root = load_object_graph(hash, src_root).identifier
      else
        @pages   = ref(:Type => :Pages, :Count => 0, :Kids => [])
        @root    = ref(:Type => :Catalog, :Pages => @pages).identifier
      end
    end

    def load_object_graph(hash, object)
      @loaded_objects ||= {}
      case object
      when Hash then
        object.each { |key,value| object[key] = load_object_graph(hash, value) }
        object
      when Array then
        object.map { |item| load_object_graph(hash, item)}
      when PDF::Reader::Reference then
        unless @loaded_objects.has_key?(object.id)
          @loaded_objects[object.id] = ref(nil)
          new_obj = load_object_graph(hash, hash[object.id])
          if new_obj.kind_of?(PDF::Reader::Stream)
            stream_dict = load_object_graph(hash, new_obj.hash)
            @loaded_objects[object.id].data = stream_dict
            @loaded_objects[object.id] << new_obj.data
          else
            @loaded_objects[object.id].data = new_obj
          end
        end
        @loaded_objects[object.id]
      when PDF::Reader::Stream
        # Stream is a subclass of string, so this is here to prevent the stream
        # being wrapped in a LiteralString
        object
      when String
        Prawn::LiteralString.new(object)
      else
        object
      end
    end

  end
end
