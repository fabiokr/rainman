require 'rainman'

# Load handlers
$:.unshift File.expand_path('..', __FILE__)
require 'domain/enom'
require 'domain/enom/nameservers'
require 'domain/opensrs'
require 'domain/opensrs/nameservers'

# The Domain module will contain all methods for interacting with various
# domain handlers.
module Domain
  extend Rainman::Driver

  register_handler :enom

  register_handler :opensrs

  namespace :nameservers do
    define_action :list
  end

  define_action :list

  define_action :transfer

  set_default_handler :opensrs
end
