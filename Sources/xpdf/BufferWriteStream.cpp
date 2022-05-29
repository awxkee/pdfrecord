//
//  BufferWriteStream.cpp
//  Document Scanner
//
//  Created by Radzivon Bartoshyk on 07/05/2022.
//

#include "BufferWriteStream.hpp"

BufferWriterStream::BufferWriterStream() {
    this->buffer = std::vector<char>();
}

char* BufferWriterStream::getBuffer(unsigned long* size) {
    *size = this->buffer.size();
    return this->buffer.data();
}

IOBasicTypes::LongFilePositionType BufferWriterStream::GetCurrentPosition() {
    return this->buffer.size();
}

IOBasicTypes::LongBufferSizeType BufferWriterStream::Write(const IOBasicTypes::Byte* inBuffer,IOBasicTypes::LongBufferSizeType inSize) {
    this->buffer.insert(this->buffer.end(), inBuffer, inBuffer + inSize);
    return inSize;
}

BufferWriterStream::~BufferWriterStream() {
    this->buffer.clear();
}
