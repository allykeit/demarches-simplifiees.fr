# frozen_string_literal: true

class Columns::ChampColumn < Column
  attr_reader :stable_id

  def initialize(procedure_id:, label:, stable_id:, tdc_type:, displayable: true, filterable: true, type: nil, options_for_select: [])
    @stable_id = stable_id
    @tdc_type = tdc_type
    type = type || self.class.type(tdc_type)
    column = tdc_type.in?(['departements', 'regions']) ? :external_id : :value

    super(
      procedure_id:,
      table: 'type_de_champ',
      column:,
      label:,
      type:,
      displayable:,
      filterable:,
      options_for_select:
    )
  end

  def value(champ)
    return if champ.nil?

    # nominal case
    if @tdc_type == champ.last_write_type_champ
      typed_value(champ)
    else
      cast_value(champ)
    end
  end

  def filtered_ids(dossiers, search_terms)
    relation = dossiers.with_type_de_champ(stable_id)

    if type == :enum
      relation.filter_exact(:champs, column, search_terms).ids
    elsif type == :enums
      relation.filter_exact_in_array(:champs, column, search_terms).ids
    else
      relation.filter_ilike(:champs, column, search_terms).ids
    end
  end

  private

  def column_id = "type_de_champ/#{stable_id}"

  def string_value(champ) = champ.public_send(column)

  def self.type(tdc_type)
    case tdc_type
    when :datetime
      :datetime
    when :date
      :date
    when :integer_number
      :integer
    when :decimal_number
      :decimal
    when :multiple_drop_down_list
      :enums
    when :drop_down_list, :departements, :regions
      :enum
    when :checkbox, :yes_no
      :boolean
    when :titre_identite, :piece_justificative
      :attachements
    else
      :text
    end
  end

  def typed_value(champ)
    value = string_value(champ)

    return if value.blank?

    case type
    when :boolean
      parse_boolean(value)
    when :integer
      value.to_i
    when :decimal
      value.to_f
    when :datetime
      parse_datetime(value)
    when :date
      parse_datetime(value)&.to_date
    when :enums
      parse_enums(value)
    else
      value
    end
  end

  def cast_value(champ)
    value = string_value(champ)

    return if value.blank?

    case [champ.last_write_type_champ, @tdc_type]
    when ['integer_number', 'decimal_number'] # recast numbers automatically
      value.to_f
    when ['decimal_number', 'integer_number'] # may lose some data, but who cares ?
      value.to_i
    when ['integer_number', 'text'], ['decimal_number', 'text'] # number to text
      value
    when ['drop_down_list', 'multiple_drop_down_list'] # single list can become multi
      [value]
    when ['drop_down_list', 'text'] # single list can become text
      value
    when ['multiple_drop_down_list', 'drop_down_list'] # multi list can become single
      parse_enums(value).first
    when ['multiple_drop_down_list', 'text'] # single list can become text
      parse_enums(value).join(', ')
    when ['date', 'datetime'] # date <=> datetime
      parse_datetime(value)&.to_datetime
    when ['datetime', 'date'] # may lose some data, but who cares ?
      parse_datetime(value)&.to_date
    else
      nil
    end
  end

  def parse_boolean(value)
    case value
    when 'true', 'on', '1'
      true
    when 'false'
      false
    end
  end

  def parse_enums(value) = JSON.parse(value) rescue nil

  def parse_datetime(value) = Time.zone.parse(value) rescue nil
end
