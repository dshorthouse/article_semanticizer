class ResolvedNameStrings < ActiveRecord::Migration
  def up
    execute "CREATE TABLE `resolved_name_strings` (
      `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
      `name_string_id` int(11) UNSIGNED NOT NULL,
      `data_source_id` int(11) NOT NULL,
      `local_id` int(11) NOT NULL,
      `gni_uuid` char(36) NOT NULL,
      `canonical_form_id` int(11) DEFAULT NULL,
      `name` varchar(255) COLLATE utf8_bin NOT NULL,
      `score` int(11) NOT NULL,
      `match_type` int(11),
      `classification_path` varchar(255) DEFAULT NULL,
      `classification_path_ranks` varchar(255) DEFAULT NULL,
      `classification_path_ids` varchar(255) DEFAULT NULL,
      `in_curated_sources` tinyint(1) DEFAULT 0,
      `finds_num` int(11),
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `idx_unique` (`name_string_id`, `data_source_id`, `local_id`),
      KEY `idx_resolved_name_strings_1` (`data_source_id`), 
      KEY `idx_resolved_name_strings_2` (`canonical_form_id`) 
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci"
  end

  def down
    drop_table :resolved_name_strings
  end
end