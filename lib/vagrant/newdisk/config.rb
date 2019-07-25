module Vagrant
  module Newdisk
    class Config < Vagrant.plugin('2', :config)
      attr_accessor :size
      attr_accessor :path
	  attr_accessor :fixed

      def initialize
        @size = UNSET_VALUE
        @path = UNSET_VALUE
		@fixed = true
      end

      def is_set?
        @size != UNSET_VALUE and @path != UNSET_VALUE
      end
    end
  end
end

