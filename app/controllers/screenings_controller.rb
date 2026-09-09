class ScreeningsController < ApplicationController
  def index
    @venues = Venue.order(:name)
    @screenings = Screening.includes(:film, :venue).order(:starts_at)
    @screenings = @screenings.where(venue_id: params[:venue_id]) if params[:venue_id].present?
    @screenings = filter_by_date(@screenings)
    @screenings = filter_by_title(@screenings)
  end

  private

  def filter_by_date(scope)
    return scope if params[:date].blank?

    scope.where(starts_at: Date.parse(params[:date]).all_day)
  rescue ArgumentError
    scope
  end

  def filter_by_title(scope)
    term = params[:q].to_s.strip
    return scope if term.blank?

    # Escape LIKE wildcards so the search term is treated as text, not SQL pattern input.
    term = ActiveRecord::Base.sanitize_sql_like(term)
    scope.joins(:film).where("films.title ILIKE ?", "%#{term}%")
  end
end
