class TitleNameString < ActiveRecord::Base
   belongs_to :article
   belongs_to :name_string
end