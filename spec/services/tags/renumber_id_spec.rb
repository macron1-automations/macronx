require 'rails_helper'

RSpec.describe Tags::RenumberId do
  let!(:tag) { create(:tag, name: 'reddit') }
  let!(:other_tag) { create(:tag, name: 'news') }

  it 'moves the tag to the new id' do
    described_class.new(old_id: tag.id, new_id: 14).call

    expect(Tag.find_by(name: 'reddit').id).to eq(14)
  end

  it 'remaps the workflows and inboxes that reference the tag' do
    workflow = create(:workflow, tag: tag)
    inbox = create(:inbox, tag: tag)
    untouched_workflow = create(:workflow, tag: other_tag)
    untouched_inbox = create(:inbox, tag: other_tag)

    result = described_class.new(old_id: tag.id, new_id: 14).call

    expect(workflow.reload.tag_id).to eq(14)
    expect(inbox.reload.tag_id).to eq(14)
    expect(untouched_workflow.reload.tag_id).to eq(other_tag.id)
    expect(untouched_inbox.reload.tag_id).to eq(other_tag.id)
    expect(result.remapped).to include('inboxes.tag_id' => 1, 'workflows.tag_id' => 1)
  end

  it 'leaves the foreign key constraints enforced' do
    workflow = create(:workflow, tag: tag)

    described_class.new(old_id: tag.id, new_id: 14).call

    expect { Workflow.where(id: workflow.id).update_all(tag_id: 9999) }
      .to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'rolls back the remap and restores the constraints when a step fails' do
    workflow = create(:workflow, tag: tag)
    connection = ActiveRecord::Base.connection
    allow(connection).to receive(:execute).and_call_original
    allow(connection).to receive(:execute).with(/ADD CONSTRAINT/).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { described_class.new(old_id: tag.id, new_id: 14).call }
      .to raise_error(ActiveRecord::StatementInvalid, 'boom')

    expect(Tag.find_by(name: 'reddit').id).to eq(tag.id)
    expect(workflow.reload.tag_id).to eq(tag.id)
    expect { Workflow.where(tag_id: tag.id).update_all(tag_id: 9999) }
      .to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'rejects an id that is already taken' do
    expect { described_class.new(old_id: tag.id, new_id: other_tag.id).call }
      .to raise_error(ArgumentError, "id #{other_tag.id} is already taken by 'news'")
  end

  it 'rejects a missing tag' do
    expect { described_class.new(old_id: 9_999, new_id: 14).call }
      .to raise_error(ArgumentError, 'no tag with id 9999')
  end

  it 'rejects non-integer and identical ids' do
    expect { described_class.new(old_id: nil, new_id: 14).call }
      .to raise_error(ArgumentError, 'OLD_ID must be an integer id')
    expect { described_class.new(old_id: 'nine', new_id: 14).call }
      .to raise_error(ArgumentError, 'OLD_ID must be an integer id')
    expect { described_class.new(old_id: ' 0 ', new_id: 14).call }
      .to raise_error(ArgumentError, 'OLD_ID must be an integer id')
    expect { described_class.new(old_id: tag.id, new_id: tag.id).call }
      .to raise_error(ArgumentError, 'OLD_ID and NEW_ID must differ')
  end
end
