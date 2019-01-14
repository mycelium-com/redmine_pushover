module RedminePushover
  class Notification

    def initialize(mail)
      @recipients = []
      @title      = mail.subject
      @message    = get_message(mail)
    end

    def get_message(mail)
      (mail.text_part || mail).body.to_s.tap do |text|
        text.sub! Setting.emails_header.strip, '' if Setting.emails_header.present?
        text.sub! /^-- ?\n.*\z/m, '' if RedminePushover::strip_signature?
        text.strip!
      end[0..1023]
    end

    def add_recipient(user)
      @recipients << user.pushover_key
    end

    def deliver!
      message = {
        message: @message,
        title:   @title
      }
      message.merge! get_priority(@message)
      t = Thread.new do
        @recipients.each do |key|
          message[:user] = key
          Pushover.send_message message
        end
      end
      t.join if Rails.env.test?
      @recipients.count
    end

    def get_priority(text)
      priority =
        if text.include?('Priority: Immediate')
          2
        elsif text.include?('Priority: Urgent')
          1
        end
      if priority == 2
        {
          priority: priority,
          retry:    240,
          expire:   10800
        }
      else
        { priority: priority }
      end
    rescue => ex
      Rails.logger.warn ex
      {}
    end
  end
end
