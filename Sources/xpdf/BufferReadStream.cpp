//
//  BufferReadStream.cpp
//  Document Scanner
//
//  Created by Radzivon Bartoshyk on 07/05/2022.
//

#include "BufferReadStream.hpp"

BufferReadStream::BufferReadStream(char* buffer, size_t size) {
    this->pointer = 0;
    this->buffer = std::vector<char>(buffer, buffer + size);
}

BufferReadStream::~BufferReadStream() {
    this->buffer.clear();
    this->pointer = 0;
}

IOBasicTypes::LongBufferSizeType BufferReadStream::Read(IOBasicTypes::Byte* inBuffer,IOBasicTypes::LongBufferSizeType inBufferSize) {
    auto bufEnd = std::min(this->buffer.begin() + this->pointer + inBufferSize, this->buffer.end());
    auto bufStart = this->buffer.begin() + this->pointer;
    std::copy(bufStart, bufEnd, inBuffer);
    this->pointer += bufEnd - bufStart;
    return bufEnd - bufStart;
}

void BufferReadStream::SetPosition(LongFilePositionType inOffsetFromStart) {
    this->pointer = inOffsetFromStart;
}

void BufferReadStream::SetPositionFromEnd(LongFilePositionType inOffsetFromEnd) {
    this->pointer = this->buffer.size() - inOffsetFromEnd;
}

LongFilePositionType BufferReadStream::GetCurrentPosition() {
    return this->pointer;
}

void BufferReadStream::Skip(LongBufferSizeType inSkipSize) {
    this->pointer = this->pointer + inSkipSize;
}

bool BufferReadStream::NotEnded() {
    return this->pointer < this->buffer.size();
}

void BufferReadStream::Reset() {
    this->pointer = 0;
}
