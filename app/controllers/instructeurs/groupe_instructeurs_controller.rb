# frozen_string_literal: true

module Instructeurs
  class GroupeInstructeursController < InstructeurController
    include EmailSanitizableConcern
    include GroupeInstructeursSignatureConcern

    before_action :ensure_allowed!

    ITEMS_PER_PAGE = 25

    def index
      @procedure = procedure
      @groupes_instructeurs = paginated_groupe_instructeurs
    end

    def show
      @procedure = procedure
      @groupe_instructeur = groupe_instructeur
      @instructeurs = paginated_instructeurs
      @maybe_typos = JSON.parse(params[:maybe_typos]) if params[:maybe_typos]
    end

    def add_instructeur
      emails_with_typos = JSON.parse(params[:emails_with_typos]) if params[:emails_with_typos]
      emails = params['emails'].presence || []
      emails.push(emails_with_typos).flatten! if emails_with_typos
      emails = check_if_typo(emails)
      errors = Array.wrap(generate_emails_suggestions_message(@maybe_typos))

      instructeurs, invalid_emails = groupe_instructeur.add_instructeurs(emails:)

      if invalid_emails.present?
        errors += [
          t('.wrong_address',
            count: invalid_emails.size,
            emails: invalid_emails.join(', '))
        ]
      end

      if instructeurs.present?
        flash[:notice] = if procedure.routing_enabled?
          t('.assignment', count: instructeurs.size,
            emails: instructeurs.map(&:email).join(', '),
            groupe: groupe_instructeur.label)
        else
          "Les instructeurs ont bien été affectés à la démarche"
        end

        known_instructeurs, not_verified_instructeurs = instructeurs.partition { |instructeur| instructeur.user.email_verified_at }

        not_verified_instructeurs.filter(&:should_receive_email_activation?).each do
          InstructeurMailer.confirm_and_notify_added_instructeur(_1, groupe_instructeur, current_instructeur.email).deliver_later
        end

        if known_instructeurs.present?
          GroupeInstructeurMailer
            .notify_added_instructeurs(groupe_instructeur, known_instructeurs, current_instructeur.email)
            .deliver_later
        end
      end

      @procedure = procedure
      @groupe_instructeur = groupe_instructeur
      @instructeurs = paginated_instructeurs

      flash[:alert] = errors.join(". ") if !errors.empty?

      query_param = { maybe_typos: @maybe_typos.to_json } if @maybe_typos.present?
      redirect_to instructeur_groupe_path(@procedure, @groupe_instructeur, query_param)
    end

    def remove_instructeur
      if groupe_instructeur.instructeurs.one?
        flash[:alert] = "Suppression impossible : il doit y avoir au moins un instructeur dans le groupe"
      else
        instructeur = Instructeur.find(instructeur_id)
        if groupe_instructeur.remove(instructeur)
          flash[:notice] = "L’instructeur « #{instructeur.email} » a été retiré du groupe."
          GroupeInstructeurMailer
            .notify_removed_instructeur(groupe_instructeur, instructeur, current_user.email)
            .deliver_later
        else
          flash[:alert] = "L’instructeur « #{instructeur.email} » n’est pas dans le groupe."
        end
      end

      redirect_to instructeur_groupe_path(procedure, groupe_instructeur)
    end

    private

    def create_instructeur(email)
      user = User.create_or_promote_to_instructeur(
        email,
        SecureRandom.hex,
        administrateurs: [procedure.administrateurs.first]
      )

      user.instructeur
    end

    def procedure
      current_instructeur
        .procedures
        .includes(:groupe_instructeurs)
        .find(params[:procedure_id])
    end

    def groupe_instructeur
      current_instructeur.groupe_instructeurs.find(params[:id])
    end

    def paginated_groupe_instructeurs
      current_instructeur
        .groupe_instructeurs
        .where(procedure: procedure)
        .page(params[:page])
        .per(ITEMS_PER_PAGE)
    end

    def paginated_instructeurs
      groupe_instructeur
        .instructeurs
        .page(params[:page])
        .per(ITEMS_PER_PAGE)
        .order(:email)
    end

    def instructeur_id
      params[:instructeur][:id]
    end

    def ensure_allowed!
      if !(current_administrateur&.owns?(procedure) || procedure.instructeurs_self_management_enabled?)
        flash[:alert] = "Vous n’avez pas le droit de gérer les instructeurs de cette démarche"
        redirect_to instructeur_procedure_path(procedure)
      end
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = "Vous n’avez pas accès à cette démarche"
      redirect_to root_path
    end
  end
end
