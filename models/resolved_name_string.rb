class ResolvedNameString < ActiveRecord::Base
  primary_keys = [:name_string_id, :data_source_id, :local_id]
  belongs_to :name_string, :foreign_key => :name_string_id
  belongs_to :resolved_canonical_form, :foreign_key => :canonical_form_id
end