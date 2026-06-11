import os
import hashlib
import struct
import math
from bitarray import bitarray
from app.core.config import settings

class BloomFilter:
    def __init__(self, expected_items: int = 10000, fpr: float = 0.01, byte_data: bytes = None):
        if byte_data:
            # Load from existing binary
            self.m = struct.unpack('>I', byte_data[0:4])[0]
            self.k = struct.unpack('>I', byte_data[4:8])[0]
            self.bit_array = bitarray()
            self.bit_array.frombytes(byte_data[8:])
        else:
            # Create new Bloom filter
            self.m = int(-expected_items * math.log(fpr) / (math.log(2) ** 2))
            # Round up to nearest multiple of 8 to ensure exact byte alignment
            self.m = (self.m + 7) & ~7
            self.k = int((self.m / expected_items) * math.log(2))
            if self.k < 1: 
                self.k = 1
            
            self.bit_array = bitarray(self.m)
            self.bit_array.setall(0)
    
    def _get_hashes(self, item: str):
        # Calculate h1 and h2 from MD5
        digest = hashlib.md5(item.encode('utf-8')).digest()
        # >I is big-endian 32-bit unsigned integer (safe for Dart cross-compat)
        h1 = struct.unpack('>I', digest[0:4])[0]
        h2 = struct.unpack('>I', digest[4:8])[0]
        
        for i in range(self.k):
            yield (h1 + i * h2) % self.m

    def add(self, item: str):
        for h in self._get_hashes(item):
            self.bit_array[h] = 1

    def __contains__(self, item: str) -> bool:
        for h in self._get_hashes(item):
            if not self.bit_array[h]:
                return False
        return True

    def to_bytes(self) -> bytes:
        # Save m and k as 4-byte integers, followed by the bit array bytes
        header = struct.pack('>II', self.m, self.k)
        return header + self.bit_array.tobytes()

class BloomFilterManager:
    def __init__(self):
        self.data_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'data')
        self.domains_file = os.path.join(self.data_dir, 'blocked_domains.txt')
        self.filter_file = os.path.join(self.data_dir, 'filter.bin')
        self.bloom_filter = None
        
        # Ensure data dir exists
        os.makedirs(self.data_dir, exist_ok=True)
        self.generate_or_load_filter()

    def generate_or_load_filter(self):
        if os.path.exists(self.filter_file):
            print("Loading existing Bloom Filter from disk...")
            with open(self.filter_file, 'rb') as f:
                self.bloom_filter = BloomFilter(byte_data=f.read())
        else:
            print("Generating new Bloom Filter...")
            # If no domains file, create a dummy one
            if not os.path.exists(self.domains_file):
                self._create_dummy_domains_file()
            
            # Count domains
            with open(self.domains_file, 'r', encoding='utf-8') as f:
                lines = [line.strip() for line in f if line.strip()]
                
            expected_items = max(10000, len(lines))
            self.bloom_filter = BloomFilter(expected_items=expected_items, fpr=0.01)
            
            for domain in lines:
                self.bloom_filter.add(domain)
                
            with open(self.filter_file, 'wb') as f:
                f.write(self.bloom_filter.to_bytes())
            print(f"Bloom Filter saved to {self.filter_file}")

    def _create_dummy_domains_file(self):
        domains = [
            "malware.com",
            "malware.test",
            "casino.com",
            "adult-content.com",
            "badsite.com",
            "phishing.org"
        ]
        # Add 10,000 dummy domains for realistic payload size
        for i in range(10000):
            domains.append(f"baddomain{i}.net")
            
        with open(self.domains_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(domains))

    def is_url_blocked(self, url: str) -> bool:
        # Simplistic parsing: remove http(s):// and path to get domain
        domain = url.replace('http://', '').replace('https://', '').split('/')[0]
        if self.bloom_filter is None:
            return False
        return domain in self.bloom_filter

bloom_manager = BloomFilterManager()
