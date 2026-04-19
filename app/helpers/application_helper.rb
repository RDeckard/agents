# frozen_string_literal: true

module ApplicationHelper
  def render_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: "_blank", rel: "noopener" })
    markdown = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, autolink: true, tables: true,
                                                 strikethrough: true)
    sanitize(markdown.render(text), tags: %w[p br strong em a ul ol li code pre h1 h2 h3 h4 h5 h6 blockquote table thead tbody tr th td hr del], # rubocop:disable Layout/LineLength
                                    attributes: %w[href target rel class])
  end
end
