# frozen_string_literal: true

class TypesDeChamp::NoEmptyDropDownValidator < ActiveModel::EachValidator
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ.filter(&:any_drop_down_list?).each do |drop_down|
      validate_drop_down_not_empty(procedure, attribute, drop_down)
    end
  end

  private

  def validate_drop_down_not_empty(procedure, attribute, drop_down)
    options = drop_down.referentiel? ? drop_down.referentiel_drop_down_options : drop_down.drop_down_options

    if options.empty?
      procedure.errors.add(
        attribute,
        procedure.errors.generate_message(attribute, :empty_drop_down, { value: drop_down.libelle }),
        type_de_champ: drop_down
      )
    end
  end
end
