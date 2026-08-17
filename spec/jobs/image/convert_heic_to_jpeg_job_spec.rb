require 'rails_helper'

RSpec.describe Image::ConvertHeicToJpegJob, type: :job do
  let!(:tag) { create(:tag, name: 'research') }
  let!(:workflow) { create(:workflow, tag: tag) }
  let(:inbox) { create(:inbox, tag: tag) }

  before { ActiveJob::Base.queue_adapter.enqueued_jobs.clear }

  def create_test_image_png
    path = Tempfile.new([ 'test_image', '.png' ]).path
    MiniMagick::Tool::Convert.new do |convert|
      convert.size '1x1'
      convert << 'xc:white'
      convert << path
    end
    path
  end

  def attach_fake_image(target_inbox, filename: 'photo.heic', content_type: 'image/heic')
    path = create_test_image_png
    target_inbox.attachments.attach(
      io: File.open(path, 'rb'),
      filename: filename,
      content_type: 'image/png'
    )
    target_inbox.attachments.last.blob.update!(content_type: content_type)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  describe '#perform' do
    context 'with heic attachments' do
      before { attach_fake_image(inbox) }

      it 'replaces heic attachment with jpeg' do
        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.count).to eq(1)
        expect(inbox.attachments.first.content_type).to eq('image/jpeg')
        expect(inbox.attachments.first.filename.to_s).to eq('photo.jpg')
      end
    end

    context 'with multiple heic attachments' do
      before do
        attach_fake_image(inbox, filename: 'first.heic')
        attach_fake_image(inbox, filename: 'second.heif', content_type: 'image/heif')
      end

      it 'converts all heic attachments' do
        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.count).to eq(2)
        expect(inbox.attachments.map(&:content_type)).to all(eq('image/jpeg'))
        expect(inbox.attachments.map { |a| a.filename.to_s }).to contain_exactly('first.jpg', 'second.jpg')
      end
    end

    context 'with mixed attachment types' do
      before do
        attach_fake_image(inbox)
        inbox.attachments.attach(
          io: StringIO.new('text data'),
          filename: 'notes.txt',
          content_type: 'text/plain'
        )
      end

      it 'only converts heic files and leaves others untouched' do
        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.count).to eq(2)
        contents = inbox.attachments.map { |a| [ a.filename.to_s, a.content_type ] }
        expect(contents).to include([ 'photo.jpg', 'image/jpeg' ])
        expect(contents).to include([ 'notes.txt', 'text/plain' ])
      end
    end

    context 'with non-heic attachments' do
      before do
        inbox.attachments.attach(
          io: StringIO.new('text data'),
          filename: 'notes.txt',
          content_type: 'text/plain'
        )
      end

      it 'does not modify any attachments' do
        expect(MiniMagick::Image).not_to receive(:new)

        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.count).to eq(1)
        expect(inbox.attachments.first.filename.to_s).to eq('notes.txt')
      end
    end

    context 'when inbox does not exist' do
      it 'returns without error' do
        expect {
          described_class.perform_now(0)
        }.not_to raise_error
      end
    end

    context 'with x-heic content type' do
      before { attach_fake_image(inbox, content_type: 'image/x-heic') }

      it 'converts x-heic to jpeg' do
        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.first.content_type).to eq('image/jpeg')
      end
    end
  end
end
