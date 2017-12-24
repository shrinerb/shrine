require "test_helper"

describe "Album form" do
  it "handles album cover photo upload" do
    visit "/"
    click_on "New Album"
    fill_in "Name", with: "My Album"
    find(".uppy-FileInput-input").set(fixture("image.jpg"))
    assert_no_selector "#album-cover-photo-upload-result[value=\"\"]"
    uploaded_file_data = find("#album-cover-photo-upload-result").value
    assert_equal %w[id storage metadata], JSON.parse(uploaded_file_data).keys
    assert_no_selector "#preview-cover-photo[value=\"\"]"
    preview_url = find("#preview-cover-photo")[:src]
    refute_empty preview_url

    click_on "Save"
    assert_no_selector ".validation-errors"
    preview_url = find("#preview-cover-photo")[:src]
    refute_empty preview_url
  end
end
