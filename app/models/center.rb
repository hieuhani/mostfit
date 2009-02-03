class Center
  include DataMapper::Resource
  
  property :id,            Serial
  property :name,          String, :length => 100, :nullable => false
  property :meeting_day,   Weekday
  property :meeting_time,  HoursAndMinutes

  belongs_to :branch
  belongs_to :manager, :child_key => [:manager_staff_id], :class_name => 'StaffMember'

  has n, :clients

  validates_present :manager

end
