class AddStatusToResolvedCanonicalForms < ActiveRecord::Migration
  def change
    add_column :resolved_canonical_forms, :vernacular_status, :integer
  end
end
    