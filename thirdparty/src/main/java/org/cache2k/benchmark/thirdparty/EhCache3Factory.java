package org.cache2k.benchmark.thirdparty;

/*
 * #%L
 * Benchmarks: third party products.
 * %%
 * Copyright (C) 2013 - 2018 headissue GmbH, Munich
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * #L%
 */

import net.sf.ehcache.CacheManager;
import org.cache2k.benchmark.BenchmarkCache;
import org.cache2k.benchmark.BenchmarkCacheFactory;
import org.ehcache.config.CacheConfiguration;
import org.ehcache.config.ResourceType;
import org.ehcache.config.builders.CacheConfigurationBuilder;
import org.ehcache.config.builders.CacheManagerBuilder;
import org.ehcache.config.builders.ResourcePoolsBuilder;

/**
 * @author Jens Wilke; created: 2013-12-08
 */
public class EhCache3Factory extends BenchmarkCacheFactory {

  static final String CACHE_NAME = "testCache";

  @Override
  protected <K, V> BenchmarkCache<K, V> createUnspecialized(final Class<K> _keyType, final Class<V> _valueType, final int _maxElements) {
    return new MyBenchmarkCache<K,V>(createCacheConfiguration(_keyType, _valueType, _maxElements));
  }

  protected <K,V> CacheConfiguration<K,V> createCacheConfiguration(final Class<K> _keyType, final Class<V> _valueType, int _maxElements) {
    return CacheConfigurationBuilder.newCacheConfigurationBuilder(_keyType, _valueType,
      ResourcePoolsBuilder.heap(_maxElements)).build();
  }

  class MyBenchmarkCache<K,V> extends BenchmarkCache<K, V> {

    CacheConfiguration config;
    org.ehcache.Cache<K,V> cache;

    MyBenchmarkCache(CacheConfiguration<K, V> cfg) {
      this.config = cfg;
      org.ehcache.CacheManager
      manager = CacheManagerBuilder.newCacheManagerBuilder().build(true);
      cache = manager.createCache(CACHE_NAME, cfg);
    }

    @Override
    public int getCacheSize() {
      return (int) config.getResourcePools().getPoolForResource(ResourceType.Core.HEAP).getSize();
    }

    @Override
    public V getIfPresent(K key) {
      return cache.get(key);
    }

    @Override
    public void put(final K key, final V value) {
      cache.put(key, value);
    }

    @Override
    public void close() {
      CacheManager.getInstance().removeCache("testCache");
    }

    @Override
    public String toString() {
      return cache.toString();
    }

  }

}
