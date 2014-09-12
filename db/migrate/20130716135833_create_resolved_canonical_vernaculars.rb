class CreateResolvedCanonicalVernaculars < ActiveRecord::Migration
  def change
    create_table :resolved_canonical_vernaculars do |t|
      t.references :resolved_canonical_form
      t.references :vernacular
      t.timestamps
    end
  end
end
    