# test con 1 author, subject_areas, merged
# test con muchos
require './bill_info'

describe BillInfo do
  it "stubs doc_locations method" do
    bill_info = BillInfo.new
    bill_info.stub(:doc_locations){["./bill_full"]}
    expect(bill_info.doc_locations).to eq(["./bill_full"])
  end
  it "reads the local doc" do
    bill_info = BillInfo.new
    bill_info.stub(:doc_locations){["./bill_full"]}
    doc = bill_info.read bill_info.doc_locations.first
    expect(doc).to be_a String
  end
  it "retrieves the info from the source" do
    bill_info = BillInfo.new
    bill_info.stub(:doc_locations){["./bill_full"]}
    doc = bill_info.read bill_info.doc_locations.first
    info = bill_info.get_info doc
    expect(info).to be_a Hash
    expect(info).not_to be_empty
  end
  it "formats the retrieved info" do
    bill_info = BillInfo.new
    bill_info.stub(:doc_locations){["./bill_full"]}
    doc = bill_info.read bill_info.doc_locations.first
    info = bill_info.get_info doc
    formatted_info = bill_info.format info
    expect(formatted_info).to be_a Billit::Bill
  end
  it "formats hashes info" do
    bill_info = BillInfo.new
    bill_info.stub(:doc_locations){["./bill_full"]}
    doc = bill_info.read bill_info.doc_locations.first
    info = bill_info.get_info doc
    formatted_info = bill_info.format info
    expect(formatted_info.authors).to be_an Array
    expect(formatted_info.authors.count).to eq(2)
    expect(formatted_info.subject_areas).to be_an Array
    expect(formatted_info.subject_areas.count).to eq(2)
    expect(formatted_info.merged_bills).to be_an Array
    expect(formatted_info.merged_bills.count).to eq(2)
  end
  it "formats voting info" do
    bill_info = BillInfo.new
    bill_info.stub(:doc_locations){["./bill_full"]}
    doc = bill_info.read bill_info.doc_locations.first
    info = bill_info.get_info doc
    formatted_info = bill_info.format info
    expect(formatted_info.motions).to be_an Array
    expect(formatted_info.motions.count).to eq(2)
    expect(formatted_info.motions.first.organization).to eq("Senado")
    expect(formatted_info.motions.first.vote_events.first.counts.first).to be_an BillitCount
    expect(formatted_info.motions.first.vote_events.first.counts.count).to eq(4)
    expect(formatted_info.motions.first.vote_events.first.votes.first).to be_a BillitVote
    expect(formatted_info.motions.first.vote_events.first.votes.count).to eq(2)
  end
  xit "formats objects info" do
  end
  xit "saves the info" do
    # bill_info.stub(:save){}
    # bill_info.save formatted_info
  end
  context "with one element information" do
    it "formats hashes info" do
      bill_info = BillInfo.new
      bill_info.stub(:doc_locations){["./bill_little"]}
      doc = bill_info.read bill_info.doc_locations.first
      info = bill_info.get_info doc
      formatted_info = bill_info.format info
      expect(formatted_info.authors).to be_an Array
      expect(formatted_info.authors.count).to eq(1)
      expect(formatted_info.subject_areas).to be_an Array
      expect(formatted_info.subject_areas.count).to eq(1)
      expect(formatted_info.merged_bills).to be_an Array
      expect(formatted_info.merged_bills.count).to eq(1)
    end
    it "formats voting info" do
      bill_info = BillInfo.new
      bill_info.stub(:doc_locations){["./bill_little"]}
      doc = bill_info.read bill_info.doc_locations.first
      info = bill_info.get_info doc
      formatted_info = bill_info.format info
      expect(formatted_info.motions).to be_an Array
      expect(formatted_info.motions.count).to eq(1)
      expect(formatted_info.motions.first.vote_events.first.counts.first).to be_an BillitCount
      expect(formatted_info.motions.first.vote_events.first.counts.count).to eq(4)
      expect(formatted_info.motions.first.vote_events.first.votes.first).to be_a BillitVote
      expect(formatted_info.motions.first.vote_events.first.votes.count).to eq(1)
    end
  end
  context "with empty information" do
    it "formats hashes info" do
      bill_info = BillInfo.new
      bill_info.stub(:doc_locations){["./bill_empty"]}
      doc = bill_info.read bill_info.doc_locations.first
      info = bill_info.get_info doc
      formatted_info = bill_info.format info
      expect(formatted_info.authors).to be_an Array
      expect(formatted_info.authors.count).to eq(0)
      expect(formatted_info.subject_areas).to be_an Array
      expect(formatted_info.subject_areas.count).to eq(0)
      expect(formatted_info.merged_bills).to be_an Array
      expect(formatted_info.merged_bills.count).to eq(0)
    end
    it "formats voting info" do
      bill_info = BillInfo.new
      bill_info.stub(:doc_locations){["./bill_empty"]}
      doc = bill_info.read bill_info.doc_locations.first
      info = bill_info.get_info doc
      formatted_info = bill_info.format info
      expect(formatted_info.motions).to be_an Array
      expect(formatted_info.motions.count).to eq(0)
    end
  end
end