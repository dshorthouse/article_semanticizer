class ResolvedCanonicalForm < ActiveRecord::Base
  has_many :vernaculars, :through => :resolved_canonical_vernaculars
  has_many :resolved_canonical_vernaculars
end