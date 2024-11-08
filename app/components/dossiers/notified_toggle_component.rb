# frozen_string_literal: true

class Dossiers::NotifiedToggleComponent < ApplicationComponent
  def initialize(procedure:, procedure_presentation:)
    @procedure = procedure
    @procedure_presentation = procedure_presentation
    @sorted_column = procedure_presentation.sorted_column
  end
end
