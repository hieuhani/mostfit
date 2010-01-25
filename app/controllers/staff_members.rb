class StaffMembers < Application
  include Pdf::DaySheet if PDF_WRITER
  include DateParser

  def index
    # @current_page = ( params[:page] && ( params[:page].to_i > 0 ) ) ? params[:page].to_i : 1 
    #per_page = 15
    # @staff_members = StaffMember.all(:order => [:id], :offset => (@current_page - 1 ) * per_page, :limit => per_page)
    @staff_members = StaffMember.paginate(:page => params[:page], :per_page => 15)
    display @staff_members
  end

  def show_centers(id)
    @staff_member = StaffMember.get(id)
    raise NotFound unless @staff_member
    @centers = @staff_member.centers
    display @centers
  end

  def show_clients(id)
    @staff_member = StaffMember.get(id)
    raise NotFound unless @staff_member
    @clients = @staff_member.centers.clients
    display @clients
  end

  def show_disbursed(id)
    @staff_member = StaffMember.get(id)
    raise NotFound unless @staff_member
    @loans = @staff_member.disbursed_loans
    display @loans
  end

  def day_sheet(id)
    @staff_member = StaffMember.get(id)
    raise NotFound unless @staff_member
    @date      = params[:date] ? parse_date(params[:date]) : Date.today
    days       = []
    days      << Center.meeting_days[@date.cwday]
    @date      = @date.holiday_bump
    days      << Center.meeting_days[@date.cwday]
    @centers   = @staff_member.centers(:meeting_day => days.uniq)
    if params[:format] == "pdf"
      generate_pdf
      send_data(File.read("#{Merb.root}/public/pdfs/staff_#{@staff_member.id}_#{@date}.pdf"), 
                :filename => "#{Merb.root}/public/pdfs/staff_#{@staff_member.id}_#{@date}.pdf")
    else
      display @centers
    end
  end

  def show(id)
    @staff_member = StaffMember.get(id)
    raise NotFound unless @staff_member
    display @staff_member
  end

  def new
    only_provides :html
    @staff_member = StaffMember.new
    display @staff_member
  end

  def edit(id)
    only_provides :html
    @staff_member = StaffMember.get(id)
    raise NotFound unless @staff_member
    display @staff_member
  end

  def create(staff_member)
    @staff_member = StaffMember.new(staff_member)
    if @staff_member.save
      redirect resource(:staff_members), :message => {:notice => "StaffMember was successfully created"}
    else
      message[:error] = "StaffMember failed to be created"
      render :new
    end
  end

  def update(id, staff_member)
    @staff_member = StaffMember.get(id)
    raise NotFound unless @staff_member
    if @staff_member.update_attributes(staff_member)
       redirect resource(:staff_members)
    else
      display @staff_member, :edit
    end
  end

  def destroy(id)
    @staff_member = StaffMember.get(id)
    raise NotFound unless @staff_member
    if @staff_member.destroy
      redirect resource(:staff_members)
    else
      raise InternalServerError
    end
  end

end # StaffMembers
