# frozen_string_literal: true

# Converts the legacy `apple_data` format from the Apnotic gem
# to the new format expected by the APNs API.
#
# Temporary compatibility layer: It will be removed in the next release.
class ActionPushNative::Service::Apns::ApnoticLegacyConverter
  APS_FIELDS = %i[
    alert badge sound content_available category url_args mutable_content thread_id
    target_content_id interruption_level relevance_score
    stale_date content_state timestamp event dismissal_date
  ].freeze
  APNS_HEADERS = %i[ expiration priority topic push_type ]

  def self.convert(apple_data)
    apple_data.each_with_object({}) do |(key, value), converted|
      if key.in?(APS_FIELDS)
        converted[:aps] ||= {}
        converted_key = key.to_s.dasherize.to_sym
        converted[:aps][converted_key] = value
        ActionPushNative.deprecator.warn("Passing the `#{key}` field directly is deprecated. Please use `.with_apple(aps: { \"#{converted_key}\": ... })` instead.")
      elsif key.in?(APNS_HEADERS)
        converted_key = "apns-#{key.to_s.dasherize}".to_sym
        converted[converted_key] = value
        ActionPushNative.deprecator.warn("Passing the `#{key}` header directly is deprecated. Please use `.with_apple(\"#{converted_key}\": ...)` instead.")
      elsif key == :apns_collapse_id
        converted_key = key.to_s.dasherize.to_sym
        converted[converted_key] = value
        ActionPushNative.deprecator.warn("Passing the `#{key}` header directly is deprecated. Please use `.with_apple(\"#{converted_key}\": ...)` instead.")
      elsif key == :custom_payload
        converted.merge!(value)
        ActionPushNative.deprecator.warn("Passing `custom_payload` is deprecated. Please use `.with_apple(#{value})` instead.")
      else
        converted[key] = value
      end
    end
  end
end
