class FeedImportsController < ApplicationController
  def new
    @feed_import = current_user.feed_imports.new
  end

  def create
    upload = params.dig(:feed_import, :csv_file)
    @feed_import = current_user.feed_imports.new(
      csv_file: upload,
      source_filename: upload&.original_filename
    )

    if @feed_import.save
      FeedImportJob.perform_later(@feed_import.id)
      redirect_to @feed_import, notice: "Feed import was queued."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @feed_import = current_user.feed_imports.find(params[:id])
  end
end
