# frozen_string_literal: true

describe Instructeurs::CellComponent do
  let(:component) { described_class.new(dossier:, column:) }

  describe '#call' do
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:types_de_champ_public) { {} }

    subject { component.call }

    context 'for email column' do
      let(:column) { dossier.procedure.columns.find(&:email?) }
      let(:user) { dossier.user }

      it { is_expected.to eq(user.email) }

      context 'when the dossier is for tiers' do
        before do
          dossier.update(for_tiers: true)
          dossier.create_individual(prenom: 'prenom', nom: 'nom')
        end

        it { is_expected.to eq("#{user.email} agit pour prenom nom") }
      end
    end

    context 'for label column' do
      let(:column) { dossier.procedure.columns.find(&:dossier_labels?) }

      before do
        dossier.labels.create(Label::GENERIC_LABELS.first)
      end

      it do
        r = %{<span class="fr-tag fr-tag--sm fr-tag--purple-glycine no-wrap">À examiner</span>}
        is_expected.to eq(r)
      end
    end

    context 'for avis column' do
      let(:column) { dossier.procedure.columns.find(&:avis?) }

      before do
        dossier.avis.create(question_answer: true)
        2.times { dossier.avis.create(question_answer: false) }
      end

      it { is_expected.to eq('oui : 1 / non : 2') }
    end

    context 'for a boolean column' do
      let(:types_de_champ_public) { [{ type: :yes_no, libelle: 'yes_no' }] }
      let(:column) { dossier.procedure.find_column(label: 'yes_no') }

      before { dossier.champs.first.update(value: 'true') }

      it { is_expected.to eq('Oui') }
    end

    context 'for a checkbox column' do
      let(:types_de_champ_public) { [{ type: :checkbox, libelle: 'checkbox' }] }
      let(:column) { dossier.procedure.find_column(label: 'checkbox') }

      before { dossier.champs.first.update(value: 'true') }

      it { is_expected.to eq('coché') }
    end

    context 'for a integer column' do
      let(:column) { dossier.procedure.find_column(label: 'Nº dossier') }

      it { is_expected.to eq(dossier.id) }
    end

    context 'for a date column' do
      let(:types_de_champ_public) { [{ type: :date, libelle: 'date' }] }
      let(:column) { dossier.procedure.find_column(label: 'date') }

      before { dossier.champs.first.update(value: Date.parse("12/02/2025")) }

      it { is_expected.to eq('12 février 2025') }
    end

    context 'for a datetime column' do
      let(:types_de_champ_public) { [{ type: :datetime, libelle: 'datetime' }] }
      let(:column) { dossier.procedure.find_column(label: 'datetime') }

      before { dossier.champs.first.update(value: DateTime.parse("12/02/2025 09:19")) }

      it { is_expected.to eq('12 février 2025 09:19') }
    end

    context 'for a date column with value as string' do
      let(:types_de_champ_public) { [{ type: :siret, libelle: 'siret' }] }
      let(:column) { dossier.procedure.find_column(label: 'siret – Entreprise date de création') }
      let(:etablissement) { build(:etablissement, entreprise_date_creation: Date.new(2015, 8, 10)) }

      before {
        dossier.champs.first.update(value: etablissement.siret, etablissement:)
        etablissement.update_champ_value_json!
      }

      it { is_expected.to eq('10 août 2015') }
    end

    context 'for a enum column' do
      let(:types_de_champ_public) { [{ type: :drop_down_list, libelle: 'drop_down_list', options: ['a', 'b', 'c'] }] }
      let(:column) { dossier.procedure.find_column(label: 'drop_down_list') }

      before { dossier.champs.first.update(value: 'b') }

      it { is_expected.to eq('b') }
    end

    context 'for a enums column' do
      let(:types_de_champ_public) { [{ type: :multiple_drop_down_list, libelle: 'multiple_drop_down_list', options: ['a', 'b', 'c'] }] }
      let(:column) { dossier.procedure.find_column(label: 'multiple_drop_down_list') }

      before { dossier.champs.first.update(value: ['b', 'c']) }

      it { is_expected.to eq('b, c') }
    end

    context 'for a nil value' do
      let(:types_de_champ_public) { [{ type: :text, libelle: 'text' }] }
      let(:column) { dossier.procedure.find_column(label: 'text') }

      it { is_expected.to eq('') }
    end

    context 'for group instructeur column' do
      let(:column) { dossier.procedure.find_column(label: 'Groupe instructeur') }

      it { is_expected.to eq('défaut') }
    end
  end
end
