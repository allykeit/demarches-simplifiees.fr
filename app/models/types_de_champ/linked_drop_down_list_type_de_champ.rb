# frozen_string_literal: true

class TypesDeChamp::LinkedDropDownListTypeDeChamp < TypesDeChamp::TypeDeChampBase
  PRIMARY_PATTERN = /^--(.*)--$/

  delegate :drop_down_options, to: :@type_de_champ
  validate :check_presence_of_primary_options

  def libelles_for_export
    path = paths.first
    [[path[:libelle], path[:path]]]
  end

  def primary_options
    primary_options = unpack_options.map(&:first)
    if primary_options.present?
      primary_options = add_blank_option_when_not_mandatory(primary_options)
    end
    primary_options
  end

  def secondary_options
    secondary_options = unpack_options.to_h
    if secondary_options.present?
      secondary_options[''] = []
    end
    secondary_options
  end

  def champ_value(champ)
    [primary_value(champ), secondary_value(champ)].filter(&:present?).join(' / ')
  end

  def champ_value_for_tag(champ, path = :value)
    case path
    when :primary
      primary_value(champ)
    when :secondary
      secondary_value(champ)
    when :value
      champ_value(champ)
    end
  end

  def champ_value_for_export(champ, path = :value)
    case path
    when :primary
      primary_value(champ)
    when :secondary
      secondary_value(champ)
    when :value
      "#{primary_value(champ) || ''};#{secondary_value(champ) || ''}"
    end
  end

  def champ_value_for_api(champ, version: 2)
    case version
    when 1
      { primary: primary_value(champ), secondary: secondary_value(champ) }
    else
      super
    end
  end

  def champ_blank?(champ)
    primary_value(champ).blank? && secondary_value(champ).blank?
  end

  def champ_blank_or_invalid?(champ)
    primary_value(champ).blank? ||
      (has_secondary_options_for_primary?(champ) && secondary_value(champ).blank?)
  end

  def columns(procedure:, displayable: true, prefix: nil)
    [
      Columns::LinkedDropDownColumn.new(
        procedure_id: procedure.id,
        label: libelle_with_prefix(prefix),
        stable_id:,
        tdc_type: type_champ,
        path: :value,
        displayable:
      ),
      Columns::LinkedDropDownColumn.new(
        procedure_id: procedure.id,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} (Primaire)",
        path: :primary,
        displayable: false,
        options_for_select: primary_options
      ),
      Columns::LinkedDropDownColumn.new(
        procedure_id: procedure.id,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} (Secondaire)",
        path: :secondary,
        displayable: false,
        options_for_select: secondary_options.values.flatten.uniq.sort
      )
    ]
  end

  private

  def add_blank_option_when_not_mandatory(options)
    return options if mandatory
    options.unshift('')
  end

  def primary_value(champ) = unpack_value(champ.value, 0)
  def secondary_value(champ) = unpack_value(champ.value, 1)
  def unpack_value(value, index) = value&.then { JSON.parse(_1)[index] rescue nil }

  def has_secondary_options_for_primary?(champ)
    primary_value(champ).present? && secondary_options[primary_value(champ)]&.any?(&:present?)
  end

  def paths
    paths = super
    paths.push({
      libelle: "#{libelle}/primaire",
      description: "#{description} (Primaire)",
      path: :primary,
      maybe_null: public? && !mandatory?
    })
    paths.push({
      libelle: "#{libelle}/secondaire",
      description: "#{description} (Secondaire)",
      path: :secondary,
      maybe_null: public? && !mandatory?
    })
    paths
  end

  def unpack_options
    chunked = drop_down_options.slice_before(PRIMARY_PATTERN)

    chunked.map do |chunk|
      primary, *secondary = chunk
      secondary = add_blank_option_when_not_mandatory(secondary)
      [PRIMARY_PATTERN.match(primary)&.[](1), secondary]
    end
  end

  def check_presence_of_primary_options
    if !PRIMARY_PATTERN.match?(drop_down_options.first)
      errors.add(libelle.presence || "La liste", "doit commencer par une entrée de menu primaire de la forme <code style='white-space: pre-wrap;'>--texte--</code>")
    end
  end
end
