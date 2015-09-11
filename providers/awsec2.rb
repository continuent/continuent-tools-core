class AWSEC2TungstenDirectoryProvider < TungstenDirectoryProvider
  DEFAULT_HOSTNAME_TAG = "Name"
  
  def self.get_regex()
    "aws\.ec2.*"
  end
  
  def get_entries(aws_info)
    hostname_tag = DEFAULT_HOSTNAME_TAG
    require_hostname_tag = false
    aws_entries = {}
    
    if aws_info.has_key?("hostname_tag")
      hostname_tag = aws_info["hostname_tag"]
      
      if aws_info.has_key?("require_hostname_tag") && aws_info["require_hostname_tag"].to_s() == "false"
        if aws_info["hostname_tag"] == DEFAULT_HOSTNAME_TAG
          # Only allow the use of DEFAULT_HOSTNAME_TAG
          require_hostname_tag = true
        else
          # Allow the use of the given tag and DEFAULT_HOSTNAME_TAG
          require_hostname_tag = false
        end
      else
        # Only allow the use of DEFAULT_HOSTNAME_TAG
        require_hostname_tag = true
      end
    end
    
    unless defined?(AWS)
      begin
        gem 'aws-sdk', '>=1.14.0', '<2.0.0'
        require 'aws/ec2'
      rescue LoadError
        raise "The aws-sdk Ruby gem or rubygem-aws-sdk package is required for this class"
      end
    end
    AWS.eager_autoload!(AWS::EC2)
    
    if aws_info.has_key?("access_key_id")
      AWS.config({
        :access_key_id => aws_info["access_key_id"]
      })
    end
    if aws_info.has_key?("secret_access_key")
      AWS.config({
        :secret_access_key => aws_info["secret_access_key"]
      })
    end
    if aws_info.has_key?("proxy_uri")
      AWS.config({
        :proxy_uri => aws_info["proxy_uri"]
      })
    end
    ec2 = AWS::EC2.new()

    region_index = -1
    region_threads = []
    region_results = []
    
    if aws_info.has_key?("regions")
      regions = aws_info["regions"]
      if regions.is_a?(String)
        regions = regions.split(",")
      end
    else
      regions = ec2.regions.map(&:name)
    end
    regions.each{|r|
      region_threads << Thread.new{
        index = Thread.exclusive{ (region_index = region_index+1) }
        region = regions[index]
        region_results[index] = {}
        TU.debug("Collect ec2_hosts from #{region}")
        
        begin
          region_ec2 = AWS::EC2.new(:region => region)
          instances = nil
          
          AWS.start_memoizing
          AWS.memoize do
            instances = region_ec2.instances().filter('instance-state-name', "running")

            if aws_info.has_key?("tag_key")
              if aws_info.has_key?("tag_value")
                instances = instances.with_tag(aws_info["tag_key"], aws_info["tag_value"])
              else
                instances = instances.tagged(aws_info["tag_key"])
              end
            else
              instances = instances.tagged('tungsten-ServerType')
            end
            instances.each{
              |ins|
              tags = ins.tags.to_h()
          
              name = tags.to_h()[hostname_tag]
            
              if name.to_s() == "" && require_hostname_tag == false
                # Allow the DEFAULT_HOSTNAME_TAG to be used as a backup
                name = tags.to_h()[DEFAULT_HOSTNAME_TAG]
              end
            
              if name.to_s() == ""
                TU.error("Unable to identify the hostname for #{ins.id} in #{region}")
              end
          
          
              if ins.vpc_id != nil
                location = ins.availability_zone + "." + ins.vpc_id
              else
                location = ins.availability_zone
              end
          
              TU.debug("Found #{ins.id}")
              region_results[index][name] = {
                'id' => ins.id.to_s(),
                'hostname' => name,
                'location' => location,
                'public-address' => ins.public_ip_address,
                'private-address' => ins.private_ip_address,
                'tags' => tags.to_h(),
                'provider' => "aws.ec2",
                'autodetect-key' => @key
              }
            }
          end
          AWS.stop_memoizing
        rescue AWS::EC2::Errors::AuthFailure => af
          TU.debug("Unable to find instances in #{region}: #{af.message}. Operation will continue.")
          AWS.stop_memoizing
        rescue => e
          TU.debug("Error finding instances in #{region}: #{e.message}")
          AWS.stop_memoizing
          raise e
        end
      }
    }
    
    region_threads.each{|t| t.join() }

    region_results.each{
      |region_result|
      aws_entries.merge!(region_result)
    }
    
    aws_entries
  end
end