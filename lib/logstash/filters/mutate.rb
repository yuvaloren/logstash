require "logstash/filters/base"
require "logstash/namespace"
require "logstash/time"

# The mutate filter allows you to do general mutations to fields. You
# can rename, remove, replace, and modify fields in your events.
#
# TODO(sissel): Support regexp replacements like String#gsub ?
class LogStash::Filters::Mutate < LogStash::Filters::Base
  config_name "mutate"

  # Rename a field.
  config :rename, :validate => :hash

  # Remove a field.
  config :remove, :validate => :array

  # Replace a field with a new value. The new value can include %{foo} strings
  config :replace, :validate => :hash

  # Convert a field's value to a different type, like turning a string to an
  # integer.
  config :convert, :validate => :hash, :required => true

  public
  def register
    valid_conversions = %w(string integer float)
    # TODO(sissel): Validate conversion requests.
    @convert.each do |field, type|
      if !valid_types.include?(type)
        @logger.error(["Invalid conversion type",
                      { "type" => type, "expected one of" => valid_types }])
        # TODO(sissel): It's 2011, man, let's actually make like.. a proper
        # 'configuration broken' exception
        raise "Bad configuration, aborting."
      end
    end # @convert.each
  end # def register

  public
  def filter(event)
    return unless event.type == @type or @type.nil?

    rename(event) if @rename
    remove(event) if @remove
    replace(event) if @replace
    convert(event) if @convert

    filter_matched(event)
  end # def filter

  private
  def remove(event)
    @remove.each do |field|
      # TODO(sissel): use event.sprintf on the field names?
      event.remove(field)
    end
  end # def remove

  private
  def rename(event)
    @rename.each do |old, new|
      # TODO(sissel): use event.sprintf on the field names?
      event[new] = event[old]
      event.remove(old)
    end
  end # def remove

  private
  def replace(event)
    # TODO(sissel): use event.sprintf on the field names?
    @replace.each do |field, newvalue|
      next unless event[field]
      event[field] = event.sprintf(newvalue)
    end
  end # def replace

  def convert(event)
    @convert.each do |field, type|
      original = event[field]

      # calls convert_{string,integer,float} depending on type requested.
      converter = method("convert_" + type)
      if original.is_a?(Hash)
        @logger.debug(["I don't know how to type convert a hash, skipping",
                      { "field" => field, "value" => original }])
        next
      elsif original.is_a?(Array)
        value = original.map { |v| converter(v) }
      else
        value = converter(value)
      end
      event[field] = value
    end
  end # def convert

  def convert_string(value)
    return value.to_s
  end # def convert_string

  def convert_integer(value)
    return value.to_i
  end # def convert_integer

  def convert_float(value)
    return value.to_f
  end # def convert_float
end # class LogStash::Filters::Mutate
