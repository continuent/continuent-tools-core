class AWSEC2TungstenDirectoryProvider < TungstenDirectoryProvider
  def self.get_regex()
    "aws\.ec2.*"
  end
  
  def get_entries(aws_info)
    aws_entries = {}
    
    unless defined?(AWS)
      begin
        require 'aws/ec2'
      rescue LoadError
        raise "The aws-sdk Ruby gem or rubygem-aws-sdk package is required for this class"
      end
    end
    
    if aws_info.has_key?("access_key_id")
      AWS.config({
        :access_key_id => Facter.value('aws_access_key')
      })
    end
    if aws_info.has_key?("aws_secret_access_key")
      AWS.config({
        :secret_access_key => Facter.value('aws_secret_access_key')
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
        
        region_ec2 = AWS::EC2.new(:region => region)
        region_ec2.instances().tagged('tungsten-ServerType').each{
          |ins|
          unless ins.status == :running
            next
          end
          
          tags = ins.tags.to_h()
          
          TU.debug("Found #{ins.id}")
          region_results[index][ins.id] = {
            'hostname' => tags.to_h()["Name"],
            'location' => ins.availability_zone,
            'public-address' => ins.public_ip_address,
            'private-address' => ins.private_ip_address,
            'tags' => tags.to_h(),
            'provider' => "aws.ec2",
            'autodetect-key' => @key
          }
        }
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