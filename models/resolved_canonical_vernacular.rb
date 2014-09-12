class ResolvedCanonicalVernacular < ActiveRecord::Base
  belongs_to :resolved_canonical_form
  belongs_to :vernacular
end