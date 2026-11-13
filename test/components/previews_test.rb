require "test_helper"

class PreviewsTest < ActionDispatch::IntegrationTest
  ViewComponent::Preview.all.each do |preview|
    preview.examples.each do |example|
      test "#{preview.preview_name}/#{example} renders" do
        get "/rails/view_components/#{preview.preview_name}/#{example}"

        assert_response :success
      end
    end
  end

  test "every component has a preview" do
    components = Dir[Rails.root.join("app/components/*_component.rb")].map { |path| File.basename(path, ".rb").camelize }
    previewed = ViewComponent::Preview.all.map { |preview| preview.name.demodulize.delete_suffix("Preview") }

    assert_empty components - previewed, "Add a Lookbook preview in test/components/previews for each of these"
  end
end
