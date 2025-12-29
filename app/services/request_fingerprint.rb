require "digest"

class RequestFingerprint
  def self.sha256_of(value)
    normalized = normalize(value)
    Digest::SHA256.hexdigest(normalized.to_json)
  end

  def self.normalize(obj)
    case obj
    when Hash
      obj.keys.sort.each_with_object({}) { |k, out| out[k] = normalize(obj[k]) }
    when Array
      obj.map { |x| normalize(x) }
    else
      obj
    end
  end
end
