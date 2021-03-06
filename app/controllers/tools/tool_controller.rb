require 'uri'

class Tools::ToolController < ApplicationController

  COOKIE_SAMPLE_CODE_SUFFIX = '_sample_code'

  before_action :set_var, :handle_cookies, :set_language

  def set_var
    @page = gon.tool = self.class::TOOL
    @is_tool = true

    if params[:language] == 'html'
      @page = 'beautify_html'
    elsif params[:language] == 'javascript'
      @page = 'beautify_js'
    elsif params[:language] == 'sql'
      @page = 'beautify_sql'
    end

    @tool = Tool.find_by_alias(self.class::TOOL)
  end

  def handle_cookies
    @theme = cookies[:theme].nil? ? 'dark' : cookies[:theme]

    set_cookie(:theme, @theme)

    unless self.class::TOOL.nil?
      if cookies[(self.class::TOOL + self.class::COOKIE_SAMPLE_CODE_SUFFIX).to_sym].nil?
        @sample_code = 'true'
        set_cookie((self.class::TOOL + self.class::COOKIE_SAMPLE_CODE_SUFFIX).to_sym, @sample_code)
      else
        @sample_code = cookies[(self.class::TOOL + self.class::COOKIE_SAMPLE_CODE_SUFFIX).to_sym]
      end
    end
  end

  def set_cookie(name, value)
    uri = URI(ENV['BASE_URL'])
    cookies[name] = {
      :value => value,
      :expires => 1.year.from_now,
      :domain => '.' + uri.host
    }
  end

  def set_language
    gon.language = params[:language] if params[:language]
  end

  def get_params; end

  def get_share_params
    is_public = params.require(:public)

    if !current_user.nil?
      name = params.require(:name)
    else
      name = ""
    end

    {is_public: is_public, name: name}
  end

  def redirect_tool
    reference_number = params[:reference_number]
    version_number = params[:version]

    if !reference_number.nil? && !version_number.nil?
      share = Share.find_by_reference_number(reference_number)

      raise NotFoundError, 'This share does not exist!' if share.nil?

      version = share.versions.find_by(version_number: version_number)

      raise NotFoundError, 'This share does not exist!' if version.nil?

      redirect_to ENV[share.tool.upcase + "_URL"] + reference_number + '/' + version_number
    end
  end

  def index
    reference_number = params[:reference_number]
    version_number = params[:version]
    gon.screenshot = params[:screenshot]

    if !reference_number.nil? && !version_number.nil?
      @share = Share.find_by_reference_number(reference_number)

      raise NotFoundError, 'This share does not exist!' if @share.nil?

      raise NotFoundError, 'Cannot find this share!' if @share.nil? || (@share.tool != self.class::TOOL)

      @version = @share.versions.find_by(version_number: version_number)

      raise NotFoundError, 'This share does not exist!' if @version.nil?

      gon.reference_number = @share.reference_number
      gon.version = @version.version_number
      gon.input = @version.input
    end
  rescue NotFoundError => e
    render_error(e.message, 404) and return
  rescue Exception => e
    render_error(e.message)
  end

  def beautify; end

  def share
    params = get_params
    share_params = get_share_params

    input = params[:input]
    tool = params[:tool]
    share = Share.create({ tool: tool })

    version = Version.create(
      {
        share: share,
        user_id: current_user.nil? ? nil : current_user.id,
        input: input,
        public: !share_params[:is_public].nil? && share_params[:is_public] == 'true',
        name: !current_user.nil? ? share_params[:name] : ""
      }
    )

    render json: {
      share_id: share.id,
      reference_number: share.reference_number,
      version: version.version_number
    }
  rescue Exception => e
    render_error(e.message) and return
  end

  def fork
    reference_number = params.require(:reference_number)
    share = Share.find_by_reference_number(reference_number)

    raise NotFoundError, 'Cannot find this share' if share.nil?

    params = get_params
    input = params[:input]

    version = Version.create({ share: share, input: input })

    render json: {
      share_id: share.id,
      reference_number: share.reference_number,
      version: version.version_number
    }
  rescue NotFoundError => e
    render_error(e.message, 404) and return
  rescue Exception => e
    render_error(e.message)
  end
end
