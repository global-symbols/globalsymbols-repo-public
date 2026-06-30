# bootstrap_form 4.5.0 relies on capture/concat inside content_tag blocks. Rails 8
# changed output-buffer nesting so markup leaks to the parent buffer and is also
# re-inserted escaped inside form-group rows.
module BootstrapForm
  module FormGroup
    def form_group(*args, &block)
      options = args.extract_options!
      name = args.first

      options[:class] = form_group_classes(options)

      inner_html = form_group_content(
        generate_label(options[:id], name, options[:label], options[:label_col], options[:layout]),
        generate_help(name, options[:help]),
        options,
        &block
      )

      content_tag(
        :div,
        inner_html,
        options.except(:append, :id, :label, :help, :icon, :input_group_class, :label_col,
                       :control_col, :add_control_col_class, :layout, :prepend)
      )
    end

    def form_group_content(label, help_text, options, &block)
      field_content = isolated_field_output(&block)

      if group_layout_horizontal?(options[:layout])
        label.to_s + content_tag(:div, field_content + help_text.to_s, class: form_group_control_class(options))
      else
        parts = [label.to_s, field_content]
        parts << help_text.to_s if help_text
        @template.safe_join(parts)
      end
    end

    def isolated_field_output(&block)
      @template.with_output_buffer do
        result = block.call
        @template.output_buffer << result if result.present?
      end.to_s
    end
  end

  module Helpers
    module Bootstrap
      def prepend_and_append_input(name, options, &block)
        options = options.extract!(:prepend, :append, :input_group_class)

        input = isolated_field_output(&block).presence || ActiveSupport::SafeBuffer.new

        input = attach_input(options, :prepend) + input + attach_input(options, :append)
        input += generate_error(name)
        options.present? &&
          input = content_tag(:div, input, class: ["input-group", options[:input_group_class]].compact)
        input
      end

      def input_with_error(name, &block)
        input = ActiveSupport::SafeBuffer.new(isolated_field_output(&block))
        input << generate_error(name)
      end

      def isolated_field_output(&block)
        @template.with_output_buffer do
          result = block.call
          @template.output_buffer << result if result.present?
        end.to_s
      end
    end
  end
end