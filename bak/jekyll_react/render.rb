require 'jekyll'

### READ:
### Copied from official Jekyll repositories
### the only purpose of this is to render liquid in a page that is being converted to JSON
### in order to enable the ability to use Liquid in a page that will be dynamically rendered later

module JekyllReact
  class Render
    attr_reader :document, :site
    attr_writer :layouts, :payload

    def initialize(site, document, site_payload = nil)
      @site     = site
      @document = document
      @payload  = site_payload
    end

    # Fetches the payload used in Liquid rendering.
    # It can be written with #payload=(new_payload)
    # Falls back to site.site_payload if no payload is set.
    #
    # Returns a Jekyll::Drops::UnifiedPayloadDrop
    def payload
      @payload ||= site.site_payload
    end

    # The list of layouts registered for this Renderer.
    # It can be written with #layouts=(new_layouts)
    # Falls back to site.layouts if no layouts are registered.
    #
    # Returns a Hash of String => Jekyll::Layout identified
    # as basename without the extension name.
    def layouts
      @layouts || site.layouts
    end

    # Determine which converters to use based on this document's
    # extension.
    #
    # Returns an array of Converter instances.
    def converters
      @converters ||= site.converters.select { |c| c.matches(document.extname) }.sort
    end

    # Determine the extname the outputted file should have
    #
    # Returns the output extname including the leading period.
    def output_ext
      @output_ext ||= (permalink_ext || converter_output_ext)
    end

    ######################
    ## DAT RENDER THO
    ######################

    def run
      Jekyll.logger.debug "Rendering:", document.relative_path

      payload["page"] = document.to_liquid

      if document.respond_to? :pager
        payload["paginator"] = document.pager.to_liquid
      end

      if document.is_a?(Jekyll::Document) && document.collection.label == "posts"
        payload["site"]["related_posts"] = document.related_posts
      else
        payload["site"]["related_posts"] = nil
      end

      # render and transform content (this becomes the final content of the object)
      payload["highlighter_prefix"] = converters.first.highlighter_prefix
      payload["highlighter_suffix"] = converters.first.highlighter_suffix

      Jekyll.logger.debug "Pre-Render Hooks:", document.relative_path
      document.trigger_hooks(:pre_render, payload)

      info = {
          :registers => { :site => site, :page => payload["page"] }
      }

      output = document.content

      if document.render_with_liquid?
        Jekyll.logger.debug "Rendering Liquid:", document.relative_path
        output = render_liquid(output, payload, info, document.path)
      end
    end

    # Convert the given content using the converters which match this renderer's document.
    #
    # content - the raw, unconverted content
    #
    # Returns the converted content.
    def convert(content)
      converters.reduce(content) do |output, converter|
        begin
          converter.convert output
        rescue => e
          Jekyll.logger.error "Conversion error:",
                              "#{converter.class} encountered an error while "\
            "converting '#{document.relative_path}':"
          Jekyll.logger.error("", e.to_s)
          raise e
        end
      end
    end

    # Render the given content with the payload and info
    #
    # content -
    # payload -
    # info    -
    # path    - (optional) the path to the file, for use in ex
    #
    # Returns the content, rendered by Liquid.
    def render_liquid(content, payload, info, path = nil)
      template = site.liquid_renderer.file(path).parse(content)
      template.warnings.each do |e|
        Jekyll.logger.warn "Liquid Warning:",
                           LiquidRenderer.format_error(e, path || document.relative_path)
      end
      template.render!(payload, info)
        # rubocop: disable RescueException
    rescue Exception => e
      Jekyll.logger.error "Liquid Exception:",
                          LiquidRenderer.format_error(e, path || document.relative_path)
      raise e
    end
    # rubocop: enable RescueException

    # Checks if the layout specified in the document actually exists
    #
    # layout - the layout to check
    #
    # Returns true if the layout is invalid, false if otherwise
    def invalid_layout?(layout)
      !document.data["layout"].nil? && layout.nil? && !(document.is_a? Jekyll::Excerpt)
    end

    # Render layouts and place given content inside.
    #
    # content - the content to be placed in the layout
    #
    #
    # Returns the content placed in the Liquid-rendered layouts
    def place_in_layouts(content, payload, info)
      output = content.dup
      layout = layouts[document.data["layout"]]

      Jekyll.logger.warn(
          "Build Warning:",
          "Layout '#{document.data["layout"]}' requested in "\
        "#{document.relative_path} does not exist."
      ) if invalid_layout? layout

      used = Set.new([layout])

      # Reset the payload layout data to ensure it starts fresh for each page.
      payload["layout"] = nil

      while layout
        payload["content"] = output
        payload["layout"]  = Jekyll::Utils.deep_merge_hashes(layout.data, payload["layout"] || {})

        output = render_liquid(
            layout.content,
            payload,
            info,
            layout.relative_path
        )

        # Add layout to dependency tree
        site.regenerator.add_dependency(
            site.in_source_dir(document.path),
            site.in_source_dir(layout.path)
        ) if document.write?

        if (layout = layouts[layout.data["layout"]])
          break if used.include?(layout)
          used << layout
        end
      end

      output
    end

    private

    def permalink_ext
      if document.permalink && !document.permalink.end_with?("/")
        permalink_ext = File.extname(document.permalink)
        permalink_ext unless permalink_ext.empty?
      end
    end

    def converter_output_ext
      if output_exts.size == 1
        output_exts.last
      else
        output_exts[-2]
      end
    end

    def output_exts
      @output_exts ||= converters.map do |c|
        c.output_ext(document.extname)
      end.compact
    end
  end
end


