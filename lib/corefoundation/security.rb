require_relative "os_status"
require_relative "sec_access_ref"
require_relative "sec_external_format"
require_relative "sec_key_import_export_flags"
require_relative "sec_item_import_export_flags"
require_relative "sec_item_import_export_key_parameters"
require_relative "dictionary"
require_relative "boolean"

module CF

    typedef :cftyperef, :secItemOrArray
    typedef :SecExternalFormat, :secExternalFormat
    typedef :SecItemImportExportFlags, :flags
    typedef SecItemImportExportKeyParameters.by_ref, :keyParams
    typedef :cfdataref, :exportedData
    typedef :pointer,:query
    typedef :cftyperef, :itemMatchResult

    attach_variable 'kSecClass', :pointer
    attach_variable 'kSecAttrLabel', :pointer
    attach_variable 'kSecClassIdentity', :pointer
    attach_variable 'kSecClassCertificate', :pointer
    attach_variable 'kSecAttrSubject', :pointer
    attach_variable 'kSecReturnRef', :pointer
    attach_variable 'kSecMatchLimit', :pointer
    attach_variable 'kSecMatchLimitOne', :pointer
    attach_variable 'kSecAttrSerialNumber', :pointer
    attach_variable 'kSecReturnAttributes', :pointer
    attach_variable 'kSecMatchLimitAll', :pointer

    attach_function 'SecItemExport' , [:secItemOrArray, :secExternalFormat,
                                         :flags, :keyParams, :exportedData], :OSStatus
    # attach_function 'SecItemImport' ,[], 
    attach_function 'SecItemCopyMatching' , [:query, :itemMatchResult], :OSStatus
    attach_function 'SecCopyErrorMessageString', [:int, :pointer], :cfstringref

    class Security
        def self.export_util(secItemOrArray, secExternalFormat, flags, keyParams, exportedData)
            return CF.SecItemExport(secItemOrArray, secExternalFormat, flags, keyParams, exportedData)
        end

        def self.export(attr_label, passphrase)
            exportedData = FFI::MemoryPointer.new :pointer
            itemMatchResult = search_cert(attr_label)
            # binding.pry
            keyParams = SecItemImportExportKeyParameters.new
            keyParams[:passphrase] = passphrase.to_cf
            puts "keyParams", keyParams.values
            status = export_util(itemMatchResult, :formatPKCS12,0,keyParams, exportedData)
            desc = CF.SecCopyErrorMessageString(status, CF::NULL)
            puts "status: #{status} - #{CF::Base.typecast(desc).to_s}"
            puts CF.show(exportedData.read_pointer)
            File.open("exportcert.p12", 'w+') { |file| file.write(CF::Base.typecast(exportedData.read_pointer).to_s) }
        end

        def self.search_item(query, result)
            status = CF.SecItemCopyMatching(query, result)
            desc = CF.SecCopyErrorMessageString(status, CF::NULL)
            itemMatchResult = result.read_pointer
            puts "status: #{status} - #{CF::Base.typecast(desc).to_s}"
            puts "itemMatchResult:", itemMatchResult
            # puts "typeofreturn", CF::String.new(CF.CFCopyDescription(itemMatchResult)).to_s
            return itemMatchResult
        end
        
        def self.search_cert(attr_label)
            result = FFI::MemoryPointer.new :pointer
            query = {}
            query[CF::Base.typecast(CF.kSecClass)] = CF::Base.typecast(CF.kSecClassIdentity)
            # query[CF::Base.typecast(CF.kSecMatchLimit)] = CF::Base.typecast(CF.kSecMatchLimitOne)
            query[CF::Base.typecast(CF.kSecAttrLabel)] = attr_label
            # query[CF::Base.typecast(CF.kSecMatchLimit)] = CF::Base.typecast(CF.kSecMatchLimitAll)
            # query[CF::Base.typecast(CF.kSecAttrSubject)] = "/C=BE/O=Test/OU=Test/CN=securtytest".to_cf
            # query[CF::Base.typecast(CF.kSecAttrSubject)] = "securtytest".to_cf
            # query[CF::Base.typecast(CF.kSecAttrSerialNumber)] = '12345'.to_cf
            query[CF::Base.typecast(CF.kSecReturnRef)] = true
            # query[CF::Base.typecast(CF.kSecReturnAttributes)] = true
           return search_item(query.to_cf, result)
        end

        def self.search_identity(query, result)
            status = CF.SecItemCopyMatching(query, result)
            desc = CF.SecCopyErrorMessageString(status, CF::NULL)
            itemMatchResult = result.read_pointer
            puts "status: #{status} - #{CF::Base.typecast(desc).to_s}"
            # puts "itemMatchResult:", itemMatchResult
            # puts "typeofreturn", CF::String.new(CF.CFCopyDescription(itemMatchResult)).to_s
            return itemMatchResult
        end

        def self.find_identity(attr_label, passphrase)
            result = FFI::MemoryPointer.new :pointer
            query = {}
            query[CF::Base.typecast(CF.kSecClass)] = CF::Base.typecast(CF.kSecClassIdentity)
            query[CF::Base.typecast(CF.kSecMatchLimit)] = CF::Base.typecast(CF.kSecMatchLimitAll)
            query[CF::Base.typecast(CF.kSecReturnAttributes)] = true
            query[CF::Base.typecast(CF.kSecReturnRef)] = true
            resultRefs = search_identity(query.to_cf, result)

            # identitiesArr =  CF::Array.new resultRefs
            identitiesArr =  CF::Base.typecast(resultRefs)
            # binding.pry
            # puts identitiesArr.to_ruby
            # puts identitiesArr.class
            identitiesCount = identitiesArr.length
            puts "Identities count", identitiesCount
            
            itemMatchResult = nil
            identitiesArr.each do |identityRef|
                if identityRef['labl'] == attr_label.to_cf
                    itemMatchResult = identityRef
                end
            end 
            puts itemMatchResult 
           
            # itemMatchResult = itemMatchResult["v_Ref"]
            secItem = CF.CFDictionaryGetValue(itemMatchResult, "v_Ref".to_cf)
           
            # puts secItem
            secIdentitiesArr =  CF::Array.mutable 
            secIdentitiesArr <<  secItem
            keyParams = SecItemImportExportKeyParameters.new
            keyParams[:passphrase] = passphrase.to_cf
            # puts "keyParams", keyParams.values
            binding.pry
            exportedData = FFI::MemoryPointer.new :pointer
            status = export_util(secIdentitiesArr.to_ptr, :formatPKCS12,0,keyParams, exportedData)
            puts status
            desc = CF.SecCopyErrorMessageString(status, CF::NULL)
            puts "status: #{status} - #{CF::Base.typecast(desc).to_s}"
            # desc = CF.SecCopyErrorMessageString(status, CF::NULL)
            # puts "status: #{status} - #{CF::Base.typecast(desc).to_s}"
            # puts CF.show(exportedData.read_pointer)
            # File.open("exportcert.p12", 'w+') { |file| file.write(CF::Base.typecast(exportedData.read_pointer).to_s) }
        end
    end
end
