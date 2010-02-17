class Occupation
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :code, String, :length => 3

  has n, :clients
  has n, :loans, :child_key => [:loan_purpose_id]

end