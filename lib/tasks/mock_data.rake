require "rubygems"

# Add the local gems dir if found within the app root; any dependencies loaded
# hereafter will try to load from the local gems before loading system gems.
if (local_gem_dir = File.join(File.dirname(__FILE__), '..', '..', 'gems')) && $BUNDLE.nil?
  $BUNDLE = true; Gem.clear_paths; Gem.path.unshift(local_gem_dir)
end

require "merb-core"

# this loads all plugins required in your init file so don't add them
# here again, Merb will do it for you
Merb.start_environment(:environment => ENV['MERB_ENV'] || 'development')


def load_fixtures(*files)
  files.each do |name|
    klass = Kernel::const_get(name.to_s.singularize.camel_case)
    yml_file =  "spec/fixtures/#{name}.yml"
    puts "\nLoading: #{yml_file}"
    entries = YAML::load_file(Merb.root / yml_file)
    entries.each do |name, entry|
      k = klass::new(entry)
      puts "#{k} :#{name}"

      if k.class == Loan  # do not update the hisotry for loans
        k.history_disabled 
      end
      unless k.save
        puts "Validation errors saving a #{klass} (##{k.id}):"
        p k.errors
        raise
      end
    end
  end
end



namespace :mock do
  desc "All in one -- load fixtures, generate payments and update the history"
  task :load_demo do
    Rake::Task['mock:fixtures'].invoke
    Rake::Task['mock:all_payments'].invoke
    Rake::Task['mock:update_history'].invoke
    puts
    puts "If all went well your demo environment has been loaded/generated... Enjoy the sandbox!"
  end

  desc "Drop current db and load fixtures from /spec/fixtures (and work the update_history jobs down)"
  task :fixtures do
    DataMapper.auto_migrate! if Merb.orm == :datamapper
    # loading is ordered, important for our references to work
    load_fixtures :users, :staff_members, :funders, :funding_lines, :branches, :centers, :clients, :loans  #, :payments
    puts
    puts "Fixtures loaded. Have a look at the mock:all_payments and mock:update_history tasks."
  end

  desc "Generate all payments for all loans without payments as if everyone paid dilligently (does not write any history)"
  task :all_payments do
    t0 = Time.now
    Merb.logger.info! "Start mock:all_payments rake task at #{t0}"
    busy_user = User.get(1)
    count = 0
    loan_ids = Loan.all.map{|l| l.id}
    loan_ids.each do |loan_id|
      sql = " INSERT INTO `payments` (`received_by_staff_id`, `principal`, `interest`, `created_by_user_id`, `loan_id`, `received_on`, `created_at`) VALUES ";
      _t0 = Time.now
      loan = Loan.get(loan_id)
      staff_member = loan.client.center.manager
      next if loan.payments.size > 0 or loan.get_status != :outstanding
      p "Doing loan No. #{loan.id}...."
      loan.history_disabled = true  # do not update the hisotry for every payment
      #      amount     = loan.total_to_be_received / loan.number_of_installments
      dates      = loan.installment_dates.reject { |x| x > Date.today or x < loan.disbursal_date }
      prin = loan.scheduled_principal_for_installment(1)
      int = loan.scheduled_interest_for_installment(1)
      values = []
      dates.each do |date|
        #prin = loan.scheduled_received_principal_up_to(date) - loan.principal_received_up_to(date)
        #int = loan.scheduled_received_interest_up_to(date) - loan.interest_received_up_to(date)
        values << "(#{staff_member.id}, #{prin}, #{int}, 1, #{loan.id}, '#{date}', now())"
        #result   = loan.repay([prin,int], busy_user, date, staff_member)
        #if result[0]  # the save status
        #  count += 1
        #else          
        #  puts "Validation errors repaying #{prin} for Loan ##{loan.id} after #{count} writes:\n#{result[1].errors.inspect}"
        #end
      end
      if not values.empty?
        sql += values.join(",")
#        debugger
        repository.adapter.execute(sql)
      end
      p "done in #{Time.now - _t0} secs\n"
    end
    t1 = Time.now
    secs = (t1 - t0).round
    Merb.logger.info! "Finished mock:all_payments rake task in #{secs} secs for #{Loan.all.size} loans creating #{count} payments, at #{t1}"
  end

  desc "Recreate the whole history"
  task :update_history do
    t0 = Time.now
    Merb.logger.info! "Start mock:history rake task at #{t0}"
    loan_ids = Loan.all.map{|l| l.id}
    loan_ids.each do |loan_id|
      loan = Loan.get(loan_id)   
      loan.update_history_bulk_insert
      print "Did loan #{loan.id}  (total = #{Time.now - t0} secs)\n"
    end
    t1 = Time.now
    secs = (t1 - t0).round
    Merb.logger.info! "Finished mock:history rake task in #{secs} secs for #{Loan.all.size} loans with #{Payment.all.size} payments, at #{t1}"
  end

  desc "Historify unhistorified loans"
  task :historify_unhistorified do
    t0 = Time.now
    Merb.logger.info! "Start mock:history rake task at #{t0}"
    Loan.all.each do |l| 
      l.update_history if l.history.blank?
    end
    t1 = Time.now
    secs = (t1 - t0).round
    Merb.logger.info! "Finished mock:history rake task in #{secs} secs for #{Loan.all.size} loans with #{Payment.all.size} payments, at #{t1}"
  end

  task :add_date_joined do
    cs = Client.all(:date_joined => nil).map{|c| c.id}
    cs.each do |id|
      c = Client.get(id)
      print "Doing client id #{c.id}..."
      c.date_joined = c.loans[0].applied_on - 1
      c.save
      print ".done \n"
    end
  end
end





# some fixture loader if found online, more features, none we need so far it seems...
# # $map = Hash.new
# # 
# # path = Merb.root / "spec" / "fixtures"
# # files = ["users", "news_items", "privs"]
# # files.reverse.each { |f| f.classify.constantize.create_table! }
# # files.map! { |f| (path / f) + ".yml" }
# # 
# # files.each do |path|
# #   puts "Processing #{path}"
# #   fixtures = YAML::load_file(path) || {}
# #   klass = File.basename(path, ".yml")
# #   klass = klass.classify.constantize
# #   fixtures.each do |name, attributes|
# #     attributes.each_pair do |key, value|
# #       if value =~ /^@/
# #         methods = value[1 .. -1].split(".")
# #         m = methods.shift
# #         value = $map[m]
# #         raise "Value is nil for key '#{m}'" if value.nil?
# #         value = value.send(methods.shift) while !methods.empty?
# #         attributes[key] = value
# #       end
# #     end
# #     object = klass.new(attributes)
# #     raise "Object invalid: #{object.inspect}\n#{object.errors.inspect}" unless object.valid?
# #     object.save
# #     raise "Key '#{name}' already exists!" if $map[name]
# #     $map[name] = object
# #   end
# # end
