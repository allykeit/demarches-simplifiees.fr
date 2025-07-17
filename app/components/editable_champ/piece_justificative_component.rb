# frozen_string_literal: true

class EditableChamp::PieceJustificativeComponent < EditableChamp::EditableChampBaseComponent
  def dsfr_input_classname
    'fr-input'
  end

  def view_as
    if @champ.dossier.brouillon?
      :link
    else
      :download
    end
  end

  def max
    if @champ.RIB?
      1
    elsif [true, nil].include?(@champ.procedure&.piece_justificative_multiple?)
      Attachment::MultipleComponent::DEFAULT_MAX_ATTACHMENTS
    else
      1
    end
  end
end
