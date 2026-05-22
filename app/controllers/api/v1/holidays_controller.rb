module Api
  module V1
    class HolidaysController < ApplicationController
      before_action :set_holiday, only: %i[show update destroy]

      def index
        authorize Holiday
        holidays = @organization.holidays.order(:date)
        render json: HolidayBlueprint.render_as_hash(holidays)
      end

      def show
        authorize @holiday
        render json: HolidayBlueprint.render_as_hash(@holiday)
      end

      def create
        authorize Holiday
        holiday = @organization.holidays.new(holiday_params)
        holiday.save!
        render json: HolidayBlueprint.render_as_hash(holiday), status: :created
      end

      def update
        authorize @holiday
        @holiday.update!(holiday_params)
        render json: HolidayBlueprint.render_as_hash(@holiday)
      end

      def destroy
        authorize @holiday
        @holiday.destroy!
        head :no_content
      end

      private

      def set_holiday
        @holiday = @organization.holidays.find(params[:id])
      end

      def holiday_params
        params.require(:holiday).permit(:name, :date, :recurring, :active)
      end
    end
  end
end
