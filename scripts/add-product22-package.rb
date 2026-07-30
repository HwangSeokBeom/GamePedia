#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Adds the local GamePediaProduct22API package to GamePedia.xcodeproj and links
# its product into the app target and the unit-test target.
#
# Kept in the repository rather than run once and forgotten: the change it makes
# is small, mechanical and easy to lose in a merge, and being able to re-run it
# is cheaper than hand-repairing a pbxproj. It is idempotent.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../GamePedia.xcodeproj', __dir__)
PACKAGE_PATH = 'Packages/GamePediaProduct22API'
# GamePediaProduct22API is the local package. OpenAPIRuntime comes from a
# package the local one depends on: the generated request/response types
# inline OpenAPIRuntime symbols (default Accept headers, the ClientMiddleware
# protocol descriptor) into whichever module calls them, so a consumer has to
# link the runtime even though it never imports it. This is the normal
# arrangement for a swift-openapi-generator client, and it does not weaken the
# rule that generated DTOs stay inside Data/Product22 — linking is not
# importing, and no app file imports OpenAPIRuntime.
PRODUCT_NAMES = %w[GamePediaProduct22API OpenAPIRuntime].freeze
TARGETS = %w[GamePedia GamePediaTests].freeze

project = Xcodeproj::Project.open(PROJECT_PATH)

# ---------------------------------------------------------------- package ref
existing = project.root_object.package_references.find do |ref|
  ref.isa == 'XCLocalSwiftPackageReference' && ref.relative_path == PACKAGE_PATH
end

if existing
  puts "= local package reference already present: #{PACKAGE_PATH}"
  package_ref = existing
else
  package_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  package_ref.relative_path = PACKAGE_PATH
  project.root_object.package_references << package_ref
  puts "+ local package reference: #{PACKAGE_PATH}"
end

# ------------------------------------------------------------- target linkage
TARGETS.each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  raise "target not found: #{target_name}" if target.nil?

  PRODUCT_NAMES.each do |product_name|
    if target.package_product_dependencies.any? { |d| d.product_name == product_name }
      puts "= #{target_name} already depends on #{product_name}"
      next
    end

    dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dependency.product_name = product_name
    # Only the local package is referenced by path; OpenAPIRuntime resolves
    # through the package graph the local package already pulls in.
    dependency.package = package_ref if product_name == 'GamePediaProduct22API'
    target.package_product_dependencies << dependency

    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dependency
    target.frameworks_build_phase.files << build_file

    puts "+ #{target_name} links #{product_name}"
  end
end

project.save
puts 'saved GamePedia.xcodeproj'
