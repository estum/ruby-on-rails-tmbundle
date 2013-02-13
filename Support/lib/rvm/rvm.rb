#!/usr/bin/env ruby

require File.join ENV['TM_BUNDLE_SUPPORT'], "lib", "rails_bundle_tools"
require File.join(TextMate.support_path, "lib", "escape")
require File.join(TextMate.support_path, "lib", "osx", "plist")

module TextMate
  class RVM
    CURRENT_RVM_VERSION = "1.17.8"
    BUTTON_OK = '1'
    BUTTON_NEW_GEMSET = '3'
    
    def choose!(message = nil)
      TextMate.exit_show_tool_tip("RVM is outdated. Update with 'rvm update'.") if outdated?
      
      button, selected = TextMate.standard_choose(message || formatted_message, gemsets, :title => "RVM Environment", :button3 => "Set a new gemset...")

      case button
      when BUTTON_OK
        create_rvmrc(gemsets[selected.to_i])
      when BUTTON_NEW_GEMSET
        parameters = { 
          "rubies"       => rubies, 
          "selectedRuby" => gemsets[selected.to_i].split('@').first, 
          'gemset'       => TextMate.project_directory.split('/').last
        }
        nib     = File.join(TextMate.bundle_support, "lib", "rvm", "nib", "SetGemset")
        command = "#{e_sh ENV['DIALOG']} -cmp #{e_sh parameters.to_plist} #{e_sh(nib)}"

        plist = OSX::PropertyList::load(`#{command}`)
        if plist['result']
          create_rvmrc "#{plist['selectedRuby']}@#{plist['result']['returnArgument']}"
        end
      end      
    end
    
   private
    def installed?
      @installed ||= File.exists?("#{TextMate.project_directory}/.rvmrc")
    end
   
    def version
      @version ||= if installed?
        rvm_version = File.open("#{TextMate.project_directory}/.rvmrc").read
        _version, gemset, n = rvm_version.scan(/rvm\s+(?:\-{1,2}[a-z]+\s+)*+([\w\.\-]+)(?:@([\w\-]+))?(?:\s+-n\s+([\w\.-]+))?/).flatten
        _version << "-#{n}" if !n.nil?
        _version << "@#{gemset}" if !gemset.nil?
        _version
      end
      
      return @version
    end
    
    def outdated?
      `rvm version`.scan(/rvm (\d+\.\d+\.\d+)/).flatten.first < CURRENT_RVM_VERSION
    end
    
    def formatted_message
      if installed? && !version.empty?
        "This project is already configured to use #{version}\n\nChange the default environment for this project: "
      else
        "Choose the default environment for this project: "
      end
    end
    
    def rubies
      @rubies ||= `rvm list strings`.split.reject { |e| e == 'default' }
    end
    
    def gemsets
      @gemsets ||= rubies.collect do |ruby|
        gemsets = `rvm #{ruby} gemset list strings`.split
        gemsets.reject! { |e| e.empty? || %w(#current * default).include?(e) }

        [ruby, gemsets.map { |g| "#{ruby}@#{g}" }]
      end.flatten
    end
    
    def create_rvmrc(gemset)
      `(cd #{TextMate.project_directory}; rvm rvmrc create #{gemset}) > /dev/null`
    end
    
  end
end

TextMate::RVM.new.choose!
