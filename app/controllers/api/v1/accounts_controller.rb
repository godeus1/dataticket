module Api
  module V1
    class AccountsController < ApplicationController
      before_action :set_account, only: %i[show update destroy organizations]

      def index
        authorize Account
        accounts = policy_scope(Account).order(:name)
        render json: AccountBlueprint.render_as_hash(accounts)
      end

      def show
        authorize @account
        render json: AccountBlueprint.render_as_hash(@account, view: :full)
      end

      def create
        authorize Account
        account = Account.create!(account_params)
        render json: AccountBlueprint.render_as_hash(account, view: :full), status: :created
      end

      def update
        authorize @account
        @account.update!(account_params)
        render json: AccountBlueprint.render_as_hash(@account, view: :full)
      end

      def destroy
        authorize @account
        @account.destroy!
        head :no_content
      end

      # GET /api/v1/accounts/:id/organizations
      # Lists all organizations managed under this MSP account
      def organizations
        authorize @account, :show?
        orgs = @account.organizations.order(:name)
        render json: orgs.map { |o|
          { id: o.id, name: o.name, slug: o.slug, timezone: o.timezone }
        }
      end

      private

      def set_account
        @account = policy_scope(Account).find(params[:id])
      end

      def account_params
        params.require(:account).permit(:name, :slug, :plan, :active)
      end
    end
  end
end
