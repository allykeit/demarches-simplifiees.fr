describe FranceConnect::ParticulierController, type: :controller do
  let(:birthdate) { '20150821' }
  let(:email) { 'EMAIL_from_fc@test.com' }

  let(:user_info) do
    {
      france_connect_particulier_id: 'blablabla',
      given_name: 'titi',
      family_name: 'toto',
      birthdate: birthdate,
      birthplace: '1234',
      gender: 'M',
      email_france_connect: email
    }
  end

  describe '#auth' do
    subject { get :login }

    it { is_expected.to have_http_status(:redirect) }
  end

  describe '#callback' do
    let(:code) { 'plop' }

    subject { get :callback, params: { code: code } }

    context 'when params are missing' do
      subject { get :callback }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when param code is missing' do
      let(:code) { nil }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when param code is empty' do
      let(:code) { '' }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when code is correct' do
      before do
        allow(FranceConnectService).to receive(:retrieve_user_informations_particulier)
          .and_return(FranceConnectInformation.new(user_info))
      end

      context 'when france_connect_particulier_id exists in database' do
        let!(:fci) { FranceConnectInformation.create!(user_info.merge(user_id: fc_user&.id)) }

        context 'and is linked to an user' do
          let(:fc_user) { create(:user, email: 'associated_user@a.com') }

          it { expect { subject }.not_to change { FranceConnectInformation.count } }
          it { expect { subject }.to change { fc_user.reload.last_sign_in_at } }

          it 'signs in with the fci associated user' do
            subject
            expect(controller.current_user).to eq(fc_user)
            expect(fc_user.reload.loged_in_with_france_connect).to eq(User.loged_in_with_france_connects.fetch(:particulier))
          end

          context 'and the user has a stored location' do
            let(:stored_location) { '/plip/plop' }
            before { controller.store_location_for(:user, stored_location) }

            it { is_expected.to redirect_to(stored_location) }
          end
        end

        context 'and is linked an instructeur' do
          let(:fc_user) { create(:instructeur, email: 'another_email@a.com').user }

          before { subject }

          it do
            expect(response).to redirect_to(new_user_session_path)
            expect(flash[:alert]).to be_present
          end
        end

        context 'and is not linked to an user' do
          let(:fc_user) { nil }

          context 'and no user with the same email exists' do
            it 'render the choose email template to select good email' do
              expect { subject }.to change { User.count }.by(0)
              expect(subject).to render_template(:choose_email)
            end

            it 'assigns the correct france_connect_email when user chooses to use FranceConnect email' do
              expect { subject }.to change { User.count }.by(0)
              expect(subject).to render_template(:choose_email)

              post :choose_email, params: { france_connect_email: email, use_france_connect_email: 'true' }

              expect(assigns(:france_connect_email)).to eq(email)
            end
          end

          context 'and an user with the same email exists' do
            let!(:preexisting_user) { create(:user, email: email) }

            it 'redirects to the merge process' do
              expect { subject }.not_to change { User.count }

              expect(response).to redirect_to(france_connect_particulier_merge_path(fci.reload.merge_token))
            end
          end
          context 'and an instructeur with the same email exists' do
            let!(:preexisting_user) { create(:instructeur, email: email) }

            it 'redirects to the merge process' do
              expect { subject }.not_to change { User.count }

              expect(response).to redirect_to(new_user_session_path)
              expect(flash[:alert]).to eq(I18n.t('errors.messages.france_connect.forbidden_html', reset_link: new_user_password_path))
            end
          end
        end
      end

      context 'when france_connect_particulier_id does not exist in database' do
        it { expect { subject }.to change { FranceConnectInformation.count }.by(1) }

        it { is_expected.to render_template(:choose_email) }
      end
    end

    context 'when code is not correct' do
      before do
        allow(FranceConnectService).to receive(:retrieve_user_informations_particulier) { raise Rack::OAuth2::Client::Error.new(500, error: 'Unknown') }
        subject
      end

      it { expect(response).to redirect_to(new_user_session_path) }

      it { expect(flash[:alert]).to be_present }
    end
  end

  describe '#associate_user' do
    subject { post :associate_user, params: { use_france_connect_email: use_france_connect_email, alternative_email: alternative_email, merge_token: merge_token } }

    let(:fci) { FranceConnectInformation.new(user_info) }
    let(:use_france_connect_email) { true }
    let(:alternative_email) { 'alt@example.com' }
    let(:merge_token) { 'valid_merge_token' }

    before do
      allow_any_instance_of(ApplicationController).to receive(:session).and_return({ merge_token: merge_token })
    end

    context 'when we are using france connect email' do
      before do
        allow(FranceConnectInformation).to receive(:find_by).with(merge_token: merge_token).and_return(fci)
        allow(fci).to receive(:valid_for_merge?).and_return(true)
        allow(fci).to receive(:associate_user!).and_return(true)
      end

      it 'renders the confirmation_sent template' do
        subject
        expect(response).to render_template(:confirmation_sent)
      end
    end

    context 'when france connect information is missing' do
      before do
        allow(controller).to receive(:securely_retrieve_fci).and_return(nil)
        subject
      end

      it 'redirects to new_user_session_path with an alert' do
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t('france_connect.particulier.associate_user.errors.unable_to_retrieve_information'))
      end
    end

    context 'when email is not present' do
      let(:use_france_connect_email) { false }
      let(:alternative_email) { nil }
      let(:fci) { instance_double(FranceConnectInformation) }

      before do
        allow(controller).to receive(:securely_retrieve_fci).and_return(fci)
        allow(fci).to receive(:email_france_connect).and_return(nil)
      end

      it 'redirects to new_user_session_path with an alert' do
        subject
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq('Veuillez fournir un email.')
      end
    end

    context 'when associating the user fails' do
      let(:fci) { instance_double(FranceConnectInformation) }
      let(:email) { 'test@example.com' }

      before do
        allow(controller).to receive(:securely_retrieve_fci).and_return(fci)
        allow(fci).to receive(:email_france_connect).and_return(email)
        allow(fci).to receive(:associate_user!).and_return(false)
      end

      it 'redirects to new_user_session_path with an alert' do
        subject
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t('france_connect.particulier.associate_user.errors.unable_to_send_confirmation'))
      end
    end

    context 'when associating the user succeeds' do
      let(:fci) { instance_double('FranceConnectInformation') }
      let(:email) { 'user@example.com' }

      before do
        allow(controller).to receive(:securely_retrieve_fci).and_return(fci)
        allow(fci).to receive(:email_france_connect).and_return(email)
        allow(fci).to receive(:associate_user!).and_return(true)
      end

      it 'calls associate_user! with the correct email' do
        expect(fci).to receive(:associate_user!).with(email)
        subject
      end

      it 'renders the confirmation sent template' do
        subject
        expect(response).to render_template(:confirmation_sent)
      end
    end
  end

  describe '#confirm_email' do
    let!(:user) { create(:user) }
    let!(:fci) { create(:france_connect_information, user: user) }

    before do
      fci.send_custom_confirmation_instructions(user)
      user.reload
    end

    let!(:expired_user_confirmation) do
      user = create(:user)
      fci = create(:france_connect_information, user: user)
      token = SecureRandom.hex(10)
      user.update!(confirmation_token: token, confirmation_sent_at: 3.days.ago)
      user
    end

    context 'when the confirmation token is valid' do
      before do
        get :confirm_email, params: { token: user.confirmation_token }
        user.reload
      end

      it 'updates the email_verified_at and confirmation_token of the user' do
        expect(user.email_verified_at).to be_present
        expect(user.confirmation_token).to be_nil
      end

      it 'redirects to the stored location or root path with a success notice' do
        expect(response).to redirect_to(root_path(user))
        expect(flash[:notice]).to eq('Votre email est bien vérifié')
      end

      it 'calls after_confirmation on the user' do
        expect(user).to receive(:after_confirmation).and_call_original
        user.after_confirmation
      end
    end

    context 'when invites are pending' do
      let!(:invite) { create(:invite, email: user.email, user: nil) }

      it 'links pending invites' do
        get :confirm_email, params: { token: user.confirmation_token }
        invite.reload
        expect(invite.user).to eq(user)
      end
    end

    context 'when the confirmation token is expired' do
      before do
        get :confirm_email, params: { token: expired_user_confirmation.confirmation_token }
      end

      it 'redirects to the resend confirmation path with an alert' do
        expect(response).to redirect_to(france_connect_resend_confirmation_path)
        expect(flash[:alert]).to eq('Lien de confirmation expiré. Un nouveau lien de confirmation a été envoyé.')
      end
    end

    context 'GET #resend_confirmation' do
      let(:user) { create(:user, email: 'test@example.com', email_verified_at: nil) }

      it 'assigns @user and renders the form' do
        get :resend_confirmation, params: { email: user.email }
        expect(assigns(:user)).to eq(user)
        expect(response).to render_template(:resend_confirmation)
      end

      it 'redirects if the email is already confirmed' do
        user.update(email_verified_at: Time.zone.now)
        get :resend_confirmation, params: { email: user.email }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Adresse email non trouvée ou déjà confirmée.')
      end

      it 'redirects if the user is not found' do
        get :resend_confirmation, params: { email: 'nonexistent@example.com' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Adresse email non trouvée ou déjà confirmée.')
      end

      it 'redirects if the user is nil' do
        get :resend_confirmation, params: { email: nil }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Adresse email non trouvée ou déjà confirmée.')
      end
    end

    context 'POST #post_resend_confirmation' do
      let(:user) { create(:user, email: 'test@example.com', email_verified_at: nil) }
      let(:fci) { create(:france_connect_information, user: user) }

      before do
        allow(User).to receive(:find_by).with(email: user.email).and_return(user)
        allow(FranceConnectInformation).to receive(:find_by).with(user: user).and_return(fci)
      end

      context 'when the user exists and email is not verified' do
        it 'sends custom confirmation instructions and redirects with notice' do
          expect(fci).to receive(:send_custom_confirmation_instructions).with(user)
          post :post_resend_confirmation, params: { email: user.email }
          expect(response).to redirect_to(root_path)
          expect(flash[:notice]).to eq('Votre lien a expiré. Demandez un nouveau lien en cliquant sur le bouton ci-dessous')
        end
      end

      context 'when the user does not exist or email is already verified' do
        let(:verified_user) { create(:user, email: 'verified@example.com', email_verified_at: Time.zone.now) }

        it 'redirects with alert for already verified email' do
          allow(User).to receive(:find_by).with(email: verified_user.email).and_return(verified_user)
          allow(FranceConnectInformation).to receive(:find_by).with(user: verified_user).and_return(fci)
          post :post_resend_confirmation, params: { email: verified_user.email }
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq('Adresse email non trouvée ou déjà confirmée.')
        end
      end
    end

    context 'when the user is not found' do
      before do
        get :confirm_email, params: { token: 'invalid_token' }
      end

      it 'redirects to the resend confirmation path with an alert' do
        expect(response).to redirect_to(france_connect_resend_confirmation_path)
        expect(flash[:alert]).to eq('Lien de confirmation expiré. Un nouveau lien de confirmation a été envoyé.')
      end
    end
  end

  RSpec.shared_examples "a method that needs a valid merge token" do
    context 'when the merge token is invalid' do
      before do
        allow(Current).to receive(:application_name).and_return('demarches-simplifiees.fr')
        merge_token
        fci.update(merge_token_created_at: 2.years.ago)
      end

      it do
        if format == :js
          subject
          expect(response.body).to eq("window.location.href='/'")
        else
          expect(subject).to redirect_to root_path
        end
        expect(flash.alert).to eq('Le délai pour fusionner les comptes FranceConnect et demarches-simplifiees.fr est expiré. Veuillez recommencer la procédure pour vous fusionner les comptes.')
      end
    end
  end

  describe '#merge' do
    let(:fci) { FranceConnectInformation.create!(user_info) }
    let(:merge_token) { fci.create_merge_token! }
    let(:format) { :html }

    subject { get :merge, params: { merge_token: merge_token } }

    context 'when the merge token is valid' do
      it { expect(subject).to have_http_status(:ok) }
    end

    it_behaves_like "a method that needs a valid merge token"

    context 'when the merge token does not exist' do
      let(:merge_token) { 'i do not exist' }

      before do
        allow(Current).to receive(:application_name).and_return('demarches-simplifiees.fr')
      end

      it do
        expect(subject).to redirect_to root_path
        expect(flash.alert).to eq("Le délai pour fusionner les comptes FranceConnect et demarches-simplifiees.fr est expiré. Veuillez recommencer la procédure pour vous fusionner les comptes.")
      end
    end
  end

  describe '#merge_with_existing_account' do
    let(:fci) { FranceConnectInformation.create!(user_info) }
    let(:merge_token) { fci.create_merge_token! }
    let(:email) { 'EXISTING_account@a.com ' }
    let(:password) { SECURE_PASSWORD }
    let(:format) { :turbo_stream }

    subject { post :merge_with_existing_account, params: { merge_token: merge_token, email: email, password: password }, format: format }

    it_behaves_like "a method that needs a valid merge token"

    context 'when the user is not found' do
      it 'does not log' do
        subject
        fci.reload

        expect(fci.user).to be_nil
        expect(fci.merge_token).not_to be_nil
        expect(controller.current_user).to be_nil
      end
    end

    context 'when the credentials are ok' do
      let!(:user) { create(:user, email: email, password: password) }

      it 'merges the account, signs in, and delete the merge token' do
        subject
        fci.reload

        expect(fci.user).to eq(user)
        expect(fci.merge_token).to be_nil
        expect(controller.current_user).to eq(user)
      end

      context 'but the targeted user is an instructeur' do
        let!(:user) { create(:instructeur, email: email, password: password).user }

        it 'redirects to the root page' do
          subject
          fci.reload

          expect(fci.user).to be_nil
          expect(fci.merge_token).not_to be_nil
          expect(controller.current_user).to be_nil
        end
      end
    end

    context 'when the credentials are not ok' do
      let!(:user) { create(:user, email: email, password: 'another password #$21$%%') }

      it 'increases the failed attempts counter' do
        subject
        fci.reload

        expect(fci.user).to be_nil
        expect(fci.merge_token).not_to be_nil
        expect(controller.current_user).to be_nil
        expect(user.reload.failed_attempts).to eq(1)
      end
    end
  end

  describe '#mail_merge_with_existing_account' do
    let(:fci) { FranceConnectInformation.create!(user_info) }
    let!(:email_merge_token) { fci.create_email_merge_token! }

    context 'when the merge_token is ok and the user is found' do
      subject { post :mail_merge_with_existing_account, params: { email_merge_token: } }

      before do
        allow(Current).to receive(:application_name).and_return('demarches-simplifiees.fr')
      end

      let!(:user) { create(:user, email: email, password: 'abcdefgh') }

      it 'merges the account, signs in, and delete the merge token' do
        subject
        fci.reload

        expect(fci.user).to eq(user)
        expect(fci.merge_token).to be_nil
        expect(fci.email_merge_token).to be_nil
        expect(controller.current_user).to eq(user)
        expect(flash[:notice]).to eq("Les comptes FranceConnect et #{Current.application_name} sont à présent fusionnés")
      end

      context 'but the targeted user is an instructeur' do
        let!(:user) { create(:instructeur, email: email, password: 'abcdefgh').user }

        it 'redirects to the new session' do
          subject
          expect(FranceConnectInformation.exists?(fci.id)).to be_falsey
          expect(controller.current_user).to be_nil
          expect(response).to redirect_to(new_user_session_path)
          expect(flash[:alert]).to eq(I18n.t('errors.messages.france_connect.forbidden_html', reset_link: new_user_password_path))
        end
      end
    end

    context 'when the email_merge_token is not ok' do
      subject { post :mail_merge_with_existing_account, params: { email_merge_token: 'ko' } }

      let!(:user) { create(:user, email: email) }

      it 'increases the failed attempts counter' do
        subject
        fci.reload

        expect(fci.user).to be_nil
        expect(fci.email_merge_token).not_to be_nil
        expect(controller.current_user).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe '#merge_with_new_account' do
    let(:fci) { FranceConnectInformation.create!(user_info) }
    let(:merge_token) { fci.create_merge_token! }
    let(:email) { ' Account@a.com ' }
    let(:format) { :turbo_stream }

    subject { post :merge_with_new_account, params: { merge_token: merge_token, email: email }, format: format }

    it_behaves_like "a method that needs a valid merge token"

    context 'when the email does not belong to any user' do
      it 'creates the account, signs in, and delete the merge token' do
        subject
        fci.reload

        expect(fci.user.email).to eq(email.downcase.strip)
        expect(fci.merge_token).to be_nil
        expect(controller.current_user).to eq(fci.user)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when an account with the same email exists' do
      let!(:user) { create(:user, email: email) }

      before { allow(controller).to receive(:sign_in).and_call_original }

      render_views

      it 'asks for the corresponding password' do
        subject
        fci.reload

        expect(fci.user).to be_nil
        expect(fci.merge_token).not_to be_nil
        expect(controller.current_user).to be_nil

        expect(response.body).to include('entrez votre mot de passe')
      end

      it 'cannot use the merge token in the email confirmation route' do
        subject
        fci.reload

        get :mail_merge_with_existing_account, params: { email_merge_token: fci.merge_token }
        expect(controller).not_to have_received(:sign_in)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe '#resend_and_renew_merge_confirmation' do
    let(:fci) { FranceConnectInformation.create!(user_info) }
    let(:merge_token) { fci.create_merge_token! }
    it 'renew token' do
      expect { post :resend_and_renew_merge_confirmation, params: { merge_token: merge_token } }.to change { fci.reload.merge_token }
      expect(fci.email_merge_token).to be_present
      expect(response).to redirect_to(france_connect_particulier_merge_path(fci.reload.merge_token))
    end
  end
end
