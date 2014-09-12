class ArticleNameString < ActiveRecord::Base
   belongs_to :article
   belongs_to :name_string
end
