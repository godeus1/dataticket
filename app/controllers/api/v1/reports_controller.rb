module Api
  module V1
    class ReportsController < ApplicationController
      def index
        authorize :report, :index?
        data = ReportService.new(@organization, report_params).call
        render json: data
      end

      private

      def report_params
        params.permit(:period, :from, :to, :assignee_id, :category_id, :priority_id)
      end
    end
  end
end
