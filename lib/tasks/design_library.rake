namespace :design_library do
  desc "Import images into the Design Library from a folder. " \
       "Filenames must match element slugs, e.g. mock-neck.png, turtle-neck.jpg. " \
       "Usage: bin/rails design_library:import[path/to/folder]"
  task :import, [:dir] => :environment do |_t, args|
    dir = args[:dir].presence || ENV["DIR"]
    abort "Pass a folder: bin/rails design_library:import[./assets] " \
          "(on Windows use DIR=... bin/rails design_library:import — rake eats backslashes " \
          "inside the brackets)" if dir.blank?
    abort "No such folder: #{dir}" unless Dir.exist?(dir)

    # Dir.glob treats "\" as an escape character, so a Windows path never
    # matches until it is normalised to forward slashes.
    pattern = File.join(File.expand_path(dir).tr("\\", "/"), "**", "*.{png,PNG,jpg,JPG,jpeg,JPEG,webp,WEBP}")
    files = Dir.glob(pattern)
    abort "No images found in #{dir}" if files.empty?

    puts "Found #{files.size} image(s) in #{dir}"

    imported = 0
    skipped = []

    files.each do |path|
      slug = File.basename(path, ".*").parameterize
      element = DesignElement.find_by(slug: slug)

      if element.nil?
        skipped << "#{File.basename(path)} — no element with slug #{slug.inspect}"
        next
      end

      # Keep the untouched upload so the asset can be reprocessed later, and
      # set it as the front layer straight away so it shows up immediately.
      File.open(path, "rb") do |file|
        element.source_image.attach(
          io: file, filename: File.basename(path),
          content_type: Marcel::MimeType.for(Pathname.new(path))
        )
      end
      element.front_image.purge if element.front_image.attached?
      File.open(path, "rb") do |file|
        element.front_image.attach(
          io: file, filename: File.basename(path),
          content_type: Marcel::MimeType.for(Pathname.new(path))
        )
      end
      element.update!(published: true, processing_status: "ready")

      # With the Python service running, queue background removal so the asset
      # becomes a proper transparent layer for the compositor.
      if AppConfig.ai_enabled?
        ProcessDesignAssetJob.perform_later(element.id)
        puts "  ✓ #{slug} → #{element.category}/#{element.name} (queued for cut-out)"
      else
        puts "  ✓ #{slug} → #{element.category}/#{element.name}"
      end

      imported += 1
    end

    puts "\nImported #{imported} image(s)."
    if skipped.any?
      puts "Skipped #{skipped.size}:"
      skipped.each { |s| puts "  · #{s}" }
      puts "\nRun bin/rails design_library:slugs to list valid filenames."
    end
  end

  desc "List every element slug, so you know what to name image files"
  task slugs: :environment do
    DesignElement.order(:category, :sort_order, :name).group_by(&:category).each do |category, elements|
      puts "\n#{category} (#{elements.size})"
      elements.each do |e|
        marker = e.front_image.attached? || e.image_url.present? ? "[image]" : "[     ]"
        parent = e.metadata["variant_of"].present? ? "  ↳ variant of #{e.metadata['variant_of']}" : ""
        puts "  #{marker} #{e.slug}#{parent}"
      end
    end
    total = DesignElement.count
    with_image = DesignElement.joins(:front_image_attachment).count
    puts "\n#{with_image} of #{total} elements have an image."
  end
end
