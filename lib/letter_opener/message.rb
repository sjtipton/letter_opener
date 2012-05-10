module LetterOpener
  class Message
    attr_reader :mail

    def self.rendered_messages(location, mail)
      messages = mail.parts.map { |part| new(location, mail, part) }
      messages << new(location, mail) if messages.empty?
      messages.each(&:render)
      messages.sort
    end

    def initialize(location, mail, part = nil)
      @location = location
      @mail = mail
      @part = part
      @attachments = []
    end

    def render
      FileUtils.mkdir_p(@location)

      if mail.attachments
        attachments_dir = File.join(@location,'attachments')
        FileUtils.mkdir_p(attachments_dir)
        mail.attachments.each do |attachment|
          path = File.join(attachments_dir, attachment.filename)
          File.open(path, 'wb') { |f| f.write(attachment.body.raw_source) }
          @attachments << [attachment.filename, "attachments/#{URI.escape(attachment.filename)}"]
        end
      end

      File.open(filepath, 'w') do |f|
        f.write ERB.new(template).result(binding)
      end
    end

    def template
      File.read(File.expand_path("../message.html.erb", __FILE__))
    end

    def filepath
      File.join(@location, "#{type}.html")
    end

    def content_type
      @part && @part.content_type || @mail.content_type
    end

    def body
      @body ||= (@part && @part.body || @mail.body).to_s
    end

    def from
      @from ||= Array(@mail.from).join(", ")
    end

    def to
      @to ||= Array(@mail.to).join(", ")
    end

    def reply_to
      @reply_to ||= Array(@mail.reply_to).join(", ")
    end

    def type
      content_type =~ /html/ ? "rich" : "plain"
    end

    def encoding
      body.respond_to?(:encoding) ? body.encoding : "utf-8"
    end

    def auto_link(text)
      text.gsub(URI.regexp(%W[https http])) do
        "<a href=\"#{$&}\">#{$&}</a>"
      end
    end

    def h(content)
      CGI.escapeHTML(content)
    end

    def <=>(other)
      order = %w[rich plain]
      order.index(type) <=> order.index(other.type)
    end
  end
end
